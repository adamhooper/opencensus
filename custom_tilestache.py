#!/usr/bin/env python

# Heavily, heavily based on Goodies.Providers.PostGeoJSON.
# Except that:
# * There's built-in path simplification
# * The DB's data is EPSG4326, not EPSG900913

__requires__ = ['TileStache==1.19.4', 'psycopg2==2.4.3', 'shapely==1.2.13']
import pkg_resources

import math
import json

from psycopg2 import connect as _connect
from psycopg2.extras import RealDictCursor

import TileStache, TileStache.Config, TileStache.Geography
from TileStache.Core import KnownUnknown
from TileStache.Goodies.Providers.PostGeoJSON import Provider

class SaveableResponse:
    """Wrapper class against a String (JSON) response that makes it behave like a PIL.Image
    """
    def __init__(self, content):
        self.content = content

    def save(self, out, format):
        if format != 'JSON':
            raise KnownUnknown('PostGeoJSON only saves .json tiles, not "%s"' % format)

        out.write(self.content)

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

        # Everything we show must be at least 40 pixels large
        minArea = metersPerPixel * metersPerPixel * 40
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
        db = _connect(self.dbdsn).cursor(cursor_factory=RealDictCursor)
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
            r.uid,
            r.type,
            r.name,
            ST_AsGeoJSON(ST_Intersection(%s, rp.geometry), %d) AS geometry_json
          FROM regions r
          INNER JOIN (
                      SELECT
                        region_id,
                        ST_Collect(polygon_zoom%d) AS geometry
                      FROM region_polygons
                      WHERE id IN (
                        SELECT id
                        FROM region_polygons
                        WHERE %f <= max_longitude
                          AND %f >= min_longitude
                          AND %f <= max_latitude
                          AND %f >= min_latitude
                          AND area_in_m > %d
                      )
                      GROUP BY region_id
                     ) rp
                  ON r.id = rp.region_id
          ORDER BY r.position
          """ % (
              bbox_padded,
              self._getFloatDecimalsForZoom(width, height, coord.zoom),
              coord.zoom,
              nw.lon, se.lon, se.lat, nw.lat,
              self._getMinAreaForZoom(width, height, coord.zoom)
              )

        f = open('out.txt', 'a')
        f.write("%s\n" % query)
        f.close()

        db.execute(query)

        rows = db.fetchall()

        features = {}
        for row in rows:
            uid = row['uid']
            properties = { 'type': row['type'] }
            geometry_json = row['geometry_json']
            features[uid] = [ properties, geometry_json ]

        if len(features) > 0:
            query2 = """
                SELECT
                    r.uid, ri.indicator_name, ri.value_year, ri.value_type, ri.value_integer, ri.value_float, ri.note
                FROM
                    region_indicators ri
                INNER JOIN regions r ON ri.region_id = r.id
                WHERE r.uid IN (%s)
                """ % (','.join([ "'%s'" % uid for uid in features.keys()]))

            db.execute(query2)
            rows2 = db.fetchall()

            for row in rows2:
                uid = row['uid']
                feature = features[uid]
                properties = feature[0]

                indicator_name = row['indicator_name']
                value_year = int(row['value_year'])
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
        for uid, feature in features.iteritems():
            properties = feature[0]
            geometry_json = feature[1]

            feature_json = '{"type":"Feature","id":%s,"properties":%s,"geometry":%s}' % (json.dumps(uid), json.dumps(properties), geometry_json)
            feature_jsons.append(feature_json)

        content = '{"type":"FeatureCollection","features":[%s]}' % (','.join(feature_jsons))

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
