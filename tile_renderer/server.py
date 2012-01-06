#!/usr/bin/env python

# Heavily based on TileStache.Goodies.Providers.PostGeoJSON.
# Except that:
# * There's built-in path simplification
# * The DB's data is EPSG4326, not EPSG900913
# * There's a UTFGrid for interaction. This isn't part of the GeoJSON spec, but it doesn't conflict with it either.

__requires__ = ['TileStache==1.19.4', 'psycopg2==2.4.3', 'shapely==1.2.13']
import pkg_resources

import TileStache, TileStache.Config

import tile_data_provider

if __name__ == '__main__':
    from datetime import datetime
    from optparse import OptionParser, OptionValueError
    import os, sys, os.path

    dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'
    config = TileStache.Config.buildConfiguration({
        'cache': {
            'name': 'Disk',
            'path': os.path.dirname(__file__) + '/cache',
            'umask': '0000'
        },
        'layers': {
            'regions': {
                'provider': {
                    'class': 'tile_data_provider:OpenCensusProvider',
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
