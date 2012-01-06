#!/usr/bin/env python

__requires__ = ['TileStache==1.19.4', 'psycopg2==2.4.3', 'shapely==1.2.13']
import pkg_resources

import TileStache, TileStache.Geography
from TileStache.Goodies.Providers.PostGeoJSON import Provider

import math
import json

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)
from psycopg2.extras import RealDictCursor

from utf_grid_builder import UTFGridBuilder

def _json_encode(s):
    return json.dumps(s, ensure_ascii = False)

class _SaveableResponse:
    """Wrapper class against a String (JSON) response that makes it behave like a PIL.Image
    """
    def __init__(self, content):
        self.content = content

    def save(self, out, format):
        if format != 'JSON':
            raise KnownUnknown('PostGeoJSON only saves .json tiles, not "%s"' % format)

        out.write(unicode(self.content).encode('utf-8'))

class OpenCensusProvider(Provider):
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

    # Get the minimum area a polygon must have to be rendered.
    #
    # We hide smaller polygons because they take long to process, both on the
    # back-end and the front-end. What's more, they make the map seem
    # cluttered. People can see the smaller polygons by zooming in.
    def _getMinAreaForZoom(self, width, height, zoom):
        zoomFactor = 2 ** (zoom - 1)

        # http://wiki.openstreetmap.org/wiki/Zoom_levels
        metersPerPixel = 78206.0 / zoomFactor

        # Everything we show must be at least 180 pixels large
        minArea = metersPerPixel * metersPerPixel * 180
        return int(minArea)

    # Get the minimum area an island must have to be rendered.
    #
    # Islands have a smaller minimum area than normal land. That's because
    # we assume landlocked polygons have larger parent polygons, so the map
    # won't seem like it's missing data. Island polygons do not have larger
    # parents, so if we omitted them there would be no data to cover up our
    # shortcut.
    def _getMinIslandAreaForZoom(self, width, height, zoom):
        zoomFactor = 2 ** (zoom - 1)

        # http://wiki.openstreetmap.org/wiki/Zoom_levels
        metersPerPixel = 78206.0 / zoomFactor

        # Every island must be at least 20 pixels large
        minArea = metersPerPixel * metersPerPixel * 20
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
            p.parents,
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
                              AND (area_in_m > %d OR (area_in_m > %d AND is_island IS TRUE))
                           ) x
                      WHERE GeometryType(geometry) IN ('POLYGON', 'MULTIPOLYGON')
                      GROUP BY region_id
                     ) rp
                  ON r.id = rp.region_id
          INNER JOIN (
                      SELECT
                        r.id AS child_region_id, STRING_AGG(CONCAT(pr.type, '-', pr.uid), '|' ORDER BY pr.position) AS parents
                      FROM regions r
                      INNER JOIN region_parents ON r.id = region_parents.region_id
                      INNER JOIN regions pr ON region_parents.parent_region_id = pr.id
                      GROUP BY r.id
                     ) p
                  ON p.child_region_id = r.id
          ORDER BY r.position
          """ % (
              self._getFloatDecimalsForZoom(width, height, coord.zoom),
              bbox_padded, coord.zoom,
              nw.lon, se.lon, se.lat, nw.lat,
              self._getMinAreaForZoom(width, height, coord.zoom),
              self._getMinIslandAreaForZoom(width, height, coord.zoom)
              )

        db.execute(query)

        rows = db.fetchall()

        utfgrid_builder = UTFGridBuilder(width, height, coord)
        features = []
        region_id_to_properties = {}

        for row in rows:
            region_id = row['id']
            json_id = '%s-%s' % (row['type'], row['uid'])
            utfgrid_builder.add(row['geometry_mercator_svg'], json_id)

            properties = { 'type': row['type'], 'uid': row['uid'], 'name': row['name'], 'json_id': json_id, 'parents': row['parents'].split('|') }
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
            feature_json = u'{"type":"Feature","id":%s,"properties":%s,"geometry":%s}' % (_json_encode(json_id), _json_encode(properties), geometry_json)
            feature_jsons.append(feature_json)

        utfgrid = utfgrid_builder.get_utfgrid_data()

        content = u'{"type":"FeatureCollection","features":[%s],"utfgrid":%s}' % (','.join(feature_jsons), _json_encode(utfgrid))

        db.close()

        return _SaveableResponse(content)
