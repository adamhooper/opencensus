#!/usr/bin/env python

# Heavily, heavily based on Goodies.Providers.PostGeoJSON.
# Except that:
# * There's built-in path simplification
# * The DB's data is EPSG4326, not EPSG900913
# * There's a UTFGrid for interaction. This isn't part of the GeoJSON spec, but it doesn't conflict with it either.

__requires__ = ['TileStache==1.19.4', 'psycopg2==2.4.3', 'shapely==1.2.13']
import pkg_resources

import math
import json
import re
import struct

import cairo

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)
from psycopg2.extras import RealDictCursor

import TileStache, TileStache.Config, TileStache.Geography
from TileStache.Core import KnownUnknown
from TileStache.Goodies.Providers.PostGeoJSON import Provider

def json_encode(s):
    return json.dumps(s, ensure_ascii = False)

# https://github.com/mapbox/mbtiles-spec/blob/master/1.1/utfgrid.md
class UTFGridCreator:
    def __init__(self, width, height, coord):
        self.keys = []
        self.width = width
        self.height = height

        self.meters_per_half_map = 20037508.34
        self.meters_per_pixel = 2 * self.meters_per_half_map / self.width / 2 ** coord.zoom
        self.pixels_per_meter = 1 / self.meters_per_pixel

        self.left = coord.column * self.width # in absolute pixels from top-left
        self.top = coord.row * self.height # in absolute pixels from top-left

        # We'll draw on a regular, non-antialiased image: color 0, color 1, etc.
        # Each color in the image is a UTFGrid-encoded id (endianness: argb)
        self.image = cairo.ImageSurface(cairo.FORMAT_RGB24, width, height)
        self.image_context = cairo.Context(self.image)
        self.image_context.set_antialias(cairo.ANTIALIAS_NONE)

        self._set_new_key('')
        self.image_context.rectangle(0, 0, width, height)
        self.image_context.fill()

    def _set_new_key(self, key):
        next_id = len(self.keys)

        encoded_id = self._encode_id(next_id)

        hex_code = hex(encoded_id)[2:].zfill(6)

        r = int(hex_code[0:2], 16) / 255.0
        g = int(hex_code[2:4], 16) / 255.0
        b = int(hex_code[4:6], 16) / 255.0

        self.image_context.set_source_rgb(r, g, b)

        self.keys.append(key)

    def add(self, svg_path, key):
        self._set_new_key(key)

        x_coord = None
        func = None

        # e.g. M 0 0 L 0 -1 1 -1 1 0 Z
        for rule in re.split('[ ,;]', svg_path):
            if rule == 'M':
                func = self.image_context.move_to
            elif rule == 'L':
                func = self.image_context.line_to
            elif rule == 'Z':
                self.image_context.close_path()
            elif x_coord is None:
                x_coord = (float(rule) + self.meters_per_half_map) * self.pixels_per_meter - self.left
            else:
                y_coord = (float(rule) + self.meters_per_half_map) * self.pixels_per_meter - self.top
                func(x_coord, y_coord)
                x_coord = None # but leave "func" alone

        self.image_context.fill()

    def _encode_id(self, id):
        encoded_id = id + 32
        if encoded_id >= 32: encoded_id += 1
        if encoded_id >= 92: encoded_id += 1
        return encoded_id

    def _get_utfgrid_grid(self):
        rows = []

        stride = self.image.get_stride()
        data = self.image.get_data()

        start = 0
        row_format = '%dI' % self.width
        row_size = self.width * 4
        for y in xrange(0, self.height):
            ints = struct.unpack(row_format, data[start:start + row_size])
            # Will be 0xff000000, 0xff000001, etc: 0xffRRGGBB
            unichars = [ unichr(x & 0xffffff) for x in ints ]
            rows.append(u''.join(unichars))
            start += stride

        return rows

    def get_utfgrid_data(self):
        return {
            'grid': self._get_utfgrid_grid(),
            'keys': self.keys
        }

class SaveableResponse:
    """Wrapper class against a String (JSON) response that makes it behave like a PIL.Image
    """
    def __init__(self, content):
        self.content = content

    def save(self, out, format):
        if format != 'JSON':
            raise KnownUnknown('PostGeoJSON only saves .json tiles, not "%s"' % format)

        out.write(unicode(self.content).encode('utf-8'))

class MyProvider(Provider):
    def __init__(self, layer, dsn):
        self.layer = layer
        self.dbdsn = dsn
        self.wgs84 = TileStache.Geography.getProjectionByName('WGS84')

    def getTypeByExtension(self, extension):
        return 'text/json', 'JSON'

    def _getDegreesPerPixel(self, width, height, zoom):
        zoomFactor = 2 ** (zoom - 1)

        # At zoom 1, each tile is ~180 degrees (east-west) and ~90 degrees (north-south)
        # At each subsequent zoom, those are divided by 2
        ewDegrees = 180.0 / zoomFactor
        nsDegrees = 90.0 / zoomFactor

        esDegreesPerPixel = ewDegrees / width
        nsDegreesPerPixel = nsDegrees / height

        return min(esDegreesPerPixel, nsDegreesPerPixel)

    def _getMinAreaForZoom(self, width, height, zoom):
        zoomFactor = 2 ** (zoom - 1)

        # http://wiki.openstreetmap.org/wiki/Zoom_levels
        metersPerPixel = 78206.0 / zoomFactor

        # Everything we show must be at least 60 pixels large
        minArea = metersPerPixel * metersPerPixel * 60
        return int(minArea)

    def _getFloatDecimalsForZoom(self, width, height, zoom):
        degreesPerPixel = self._getDegreesPerPixel(width, height, zoom)

        # 1 degree -> precision 0
        # 0.1 degree -> precision 1
        # 0.01 degree -> precision 2
        # 0.001 degree -> precision 3
        # And we want to make sure we don't go over a 1/2-pixel inaccuracy

        return int(math.ceil(-math.log10(degreesPerPixel / 2)))

    def renderTile(self, width, height, srs, coord):
        db = psycopg2.connect(self.dbdsn).cursor(cursor_factory=RealDictCursor)
        db.execute("SET work_mem TO '1024MB'")

        nw = self.layer.projection.coordinateLocation(coord)
        se = self.layer.projection.coordinateLocation(coord.right().down())

        # We pad our response by 1% per side. That's about 2px per side. If we didn't, the
        # clip edges of our polygons would be rendered on the client side with 1px strokes.
        nw_padded = self.layer.projection.coordinateLocation(coord.left(0.01).up(0.01))
        se_padded = self.layer.projection.coordinateLocation(coord.right(1.01).down(1.01))

        #bbox = 'ST_MakeBox2D(ST_MakePoint(%.12f, %.12f), ST_MakePoint(%.12f, %.12f))' % (nw.lon, nw.lat, se.lon, se.lat)
        bbox_padded = 'ST_MakeBox2D(ST_MakePoint(%.12f, %.12f), ST_MakePoint(%.12f, %.12f))' % (nw_padded.lon, nw_padded.lat, se_padded.lon, se_padded.lat)

        query = """
          SELECT
            r.id,
            r.uid,
            r.type,
            r.name,
            ST_AsGeoJSON(rp.geometry, %d) AS geometry_json,
            ST_AsSVG(ST_Transform(ST_SetSRID(rp.geometry, 4326), 900913)) AS geometry_mercator_svg
          FROM regions r
          INNER JOIN (
                      SELECT
                        region_id,
                        ST_Collect(geometry) AS geometry
                      FROM (
                            SELECT
                              region_id,
                              ST_Intersection(%s, polygon_zoom%d) AS geometry
                            FROM region_polygons
                            WHERE %f <= max_longitude
                              AND %f >= min_longitude
                              AND %f <= max_latitude
                              AND %f >= min_latitude
                              AND area_in_m > %d
                           ) x
                      WHERE GeometryType(geometry) IN ('POLYGON', 'MULTIPOLYGON')
                      GROUP BY region_id
                     ) rp
                  ON r.id = rp.region_id
          ORDER BY r.position
          """ % (
              self._getFloatDecimalsForZoom(width, height, coord.zoom),
              bbox_padded, coord.zoom,
              nw.lon, se.lon, se.lat, nw.lat,
              self._getMinAreaForZoom(width, height, coord.zoom),
              )

        db.execute(query)

        rows = db.fetchall()

        utfgrid_creator = UTFGridCreator(width, height, coord)
        features = []
        region_id_to_properties = {}

        for row in rows:
            region_id = row['id']
            json_id = '%s-%s' % (row['type'], row['uid'])
            utfgrid_creator.add(row['geometry_mercator_svg'], json_id)

            properties = { 'type': row['type'], 'uid': row['uid'], 'name': row['name'], 'json_id': json_id }
            geometry_json = row['geometry_json']

            feature = [ properties, geometry_json ]

            region_id_to_properties[region_id] = properties
            features.append(feature)

        if len(features) > 0:
            query2 = """
                SELECT
                    v.region_id, i.name, v.year, i.value_type, v.value_integer, v.value_float, v.note
                FROM
                    indicator_region_values v
                INNER JOIN indicators i ON v.indicator_id = i.id
                WHERE v.region_id IN (%s)
                """ % (','.join([ "'%s'" % region_id for region_id in region_id_to_properties.keys() ]))

            db.execute(query2)
            rows2 = db.fetchall()

            for row in rows2:
                region_id = row['region_id']
                properties = region_id_to_properties[region_id]

                indicator_name = row['name']
                value_year = int(row['year'])
                value_type = row['value_type']
                value = None
                if value_type == 'integer':
                    value = int(row['value_integer'])
                elif value_type == 'float':
                    value = float(row['value_float'])
                else:
                    raise Exception('Unknown value type %r' % value_type)
                note = row['note']

                if value_year not in properties: properties[value_year] = {}
                properties[value_year][indicator_name] = value
                if note is not None and note != '':
                    properties[value_year]["%s-note" % indicator_name] = note

        feature_jsons = []
        for properties, geometry_json in features:
            json_id = properties.pop('json_id')
            feature_json = u'{"type":"Feature","id":%s,"properties":%s,"geometry":%s}' % (json_encode(json_id), json_encode(properties), geometry_json)
            feature_jsons.append(feature_json)

        utfgrid = utfgrid_creator.get_utfgrid_data()

        content = u'{"type":"FeatureCollection","features":[%s],"utfgrid":%s}' % (','.join(feature_jsons), json_encode(utfgrid))

        db.close()

        return SaveableResponse(content)

if __name__ == '__main__':
    from datetime import datetime
    from optparse import OptionParser, OptionValueError
    import os, sys

    dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'
    config = TileStache.Config.buildConfiguration({
        'cache': {
            'name': 'Disk',
            'path': './tmp/cache/tilestache',
            'umask': '0000'
        },
        'layers': {
            'regions': {
                'provider': {
                    'class': '__main__:MyProvider',
                    'kwargs': { 'dsn': dsn }
                },
                'bounds': {
                    'low': 0,
                    'high': 18,
                    'north': 90,
                    'west': -141.00198,
                    'east': -52.63,
                    'south': 41.69
                },
                'preview': {
                    'lat': 45.5,
                    'lon': -73.5,
                    'zoom': 9,
                    'ext': 'geojson'
                },
                'allowed origin': '*'
            }
        }
    })

    from werkzeug.serving import run_simple

    app = TileStache.WSGITileServer(config=config, autoreload=True)
    run_simple('localhost', 8000, app)
