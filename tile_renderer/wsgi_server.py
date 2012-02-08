#!/usr/bin/env python

import json
import re
import sqlite3
import zlib

TILES_DB = 'mbtiles.sqlite3'
STATS_DB = 'statistics.sqlite3'

_URL_REGEX = re.compile('^/regions/(?P<zoom_level>\d\d*)/(?P<column>\d\d*)/(?P<row>\d\d*)\.(?:geo)?json$')

_tiles_cursor = None
_stats_cursor = None

def _connect_tiles_cursor():
    db = sqlite3.connect(TILES_DB)
    global _tiles_cursor
    _tiles_cursor = db.cursor()

def _connect_stats_cursor():
    db = sqlite3.connect(STATS_DB)
    global _stats_cursor
    _stats_cursor = db.cursor()

def _get_statistics(region_ids):
    if _stats_cursor is None: _connect_stats_cursor()

    q = 'SELECT region_id, statistics FROM region_statistics WHERE region_id IN (%s)' % (','.join(map(str, region_ids)),)
    _stats_cursor.execute(q)

    ret = {}

    for region_id, statistics_z in _stats_cursor:
        u = zlib.decompress(statistics_z).decode('utf-8')
        statistics = json.loads(u)

        ret[region_id] = statistics

    return ret

def _get_tile_data(zoom_level, row, column):
    if _tiles_cursor is None: _connect_tiles_cursor()

    _tiles_cursor.execute('SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_row = ? AND tile_column = ?', (zoom_level, row, column))
    row = _tiles_cursor.fetchone()

    if row is None: return None

    u = zlib.decompress(row[0]).decode('utf-8')
    data = json.loads(u)

    return data

def _build_region_dictionary_across_tile_data(tile_data):
    regions = {}

    for feature in tile_data['features']:
        if 'statistics' in feature['properties']:
            properties = feature['properties']
            statistics = properties['statistics']
            if '0' in statistics:
                region_id = statistics['0']['TO-FILL']['value']
                regions[region_id] = properties

    return regions

def application(env, start_response):
    url_match = _URL_REGEX.match(env['PATH_INFO'])

    if not url_match:
        start_response('404 Not Found', [('Content-Type', 'text/plain')])
        return ['Invalid URL %s. Should be "/<zoom_level>/<row>/<column>.json"' % (env['PATH_INFO'],)]

    zoom_level = int(url_match.group('zoom_level'))
    row = int(url_match.group('row'))
    column = int(url_match.group('column'))

    tile_data = _get_tile_data(zoom_level, row, column)

    if tile_data is None:
        start_response('400 Not Found', [
            ('Content-Type', 'text/plain'),
            ('Access-Control-Allow-Origin', 'http://opencensus.adamhooper.com')
        ])
        return ['Tile not found']

    # Build a dictionary that points to the parts of tile_data we want
    # to modify
    regions = _build_region_dictionary_across_tile_data(tile_data)

    # Modify the tile data with new statistics
    if len(regions) > 0:
        region_to_statistics = _get_statistics(regions.keys())
        for region_id, statistics in region_to_statistics.items():
            regions[region_id]['statistics'] = statistics

    # Encode the result
    ustring = json.dumps(tile_data, ensure_ascii=False, check_circular=False, separators=(',', ':'))
    utf8string = ustring.encode('utf-8')

    start_response('200 OK', [
        ('Content-Type', 'application/json;charset=UTF-8'),
        ('Content-Length', str(len(utf8string))),
        ('Access-Control-Allow-Origin', 'http://opencensus.adamhooper.com')
    ])
    return [utf8string]
