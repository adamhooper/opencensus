#!/usr/bin/env python

# Heavily, heavily based on Goodies.Providers.PostGeoJSON.
# Except that:
# * There's built-in path simplification
# * The DB's data is EPSG4326, not EPSG900913

__requires__ = ['TileStache==1.19.4', 'psycopg2==2.4.3', 'shapely==1.2.13']
import pkg_resources

from binascii import unhexlify as _unhexlify

from psycopg2 import connect as _connect
from psycopg2.extras import RealDictCursor
from TileStache.Goodies.Providers.PostGeoJSON import SaveableResponse, row2feature, shape2geometry, _InvisibleBike, Provider
import TileStache, TileStache.Config, TileStache.Geography

class MyProvider(Provider):
    def __init__(self, layer, dsn, indent=0, precision=6):
        self.layer = layer
        self.dbdsn = dsn
        self.wgs84 = TileStache.Geography.getProjectionByName('WGS84')
        self.indent = indent
        self.precision = precision

    def getTypeByExtension(self, extension):
        return 'text/json', 'JSON'

    def _getToleranceForSimplify(self, width, height, zoom):
        zoomFactor = 2 ** (zoom - 1)

        # At zoom 1, each tile is ~180 degrees (east-west) and ~90 degrees (north-south)
        # At each subsequent zoom, those are divided by 2
        ewDegrees = 180.0 / zoomFactor
        nsDegrees = 90.0 / zoomFactor

        esDegreesPerPixel = ewDegrees / width
        nsDegreesPerPixel = nsDegrees / height

        # we'll tolerate inaccuracies of up to 1/1.5 of a pixel
        esTolerance = (esDegreesPerPixel / 1.5)
        nsTolerance = (nsDegrees / 1.5)

        if esTolerance < nsTolerance:
            return esTolerance
        else:
            return nsTolerance

    def _getMinAreaForZoom(self, width, height, zoom):
        zoomFactor = 2 ** (zoom - 1)

        # http://wiki.openstreetmap.org/wiki/Zoom_levels
        metersPerPixel = 78206.0 / zoomFactor

        # Everything we show must be at least 40 pixels large
        minArea = metersPerPixel * metersPerPixel * 40
        return int(minArea)

    def renderTile(self, width, height, srs, coord):
        nw = self.layer.projection.coordinateLocation(coord)
        se = self.layer.projection.coordinateLocation(coord.right().down())

        ul = self.wgs84.locationProj(nw)
        lr = self.wgs84.locationProj(se)

        bbox = 'ST_MakeBox2D(ST_MakePoint(%.6f, %.6f), ST_MakePoint(%.6f, %.6f))' % (ul.x, ul.y, lr.x, lr.y)

        query = """
          SELECT
            r.uid,
            r.type,
            r.name,
            ST_Multi(ST_Collect(ST_Intersection(%s, ST_SimplifyPreserveTopology(rp.polygon, %f)))) AS geometry
          FROM regions r
          INNER JOIN region_polygons rp
                  ON r.id = rp.region_id
                 AND rp.polygon && %s
                 AND rp.area_in_m > %d
          INNER JOIN region_types rt
                  ON r.type = rt.type
          GROUP BY r.uid, r.name, r.type, rt.position
          ORDER BY SUM(rp.area_in_m) DESC, rt.position
          """ % (
              bbox,
              self._getToleranceForSimplify(width, height, coord.zoom),
              bbox,
              self._getMinAreaForZoom(width, height, coord.zoom)
              )

        db = _connect(self.dbdsn).cursor(cursor_factory=RealDictCursor)

        f = open('out.txt', 'a')
        f.write("%s\n" % query)
        f.close()

        db.execute(query)
        rows = db.fetchall()

        db.close()

        response = {'type': 'FeatureCollection', 'features': []}

        for row in rows:
            feature = row2feature(row, 'uid', 'geometry')
            feature['id'] = "uid-%s" % feature['id']

            try:
                geom = shape2geometry(feature['geometry'], self.wgs84, None)
            except _InvisibleBike:
                # don't output this geometry because it's empty
                pass
            else:
                feature['geometry'] = geom
                response['features'].append(feature)

        return SaveableResponse(response, self.indent, self.precision)

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
