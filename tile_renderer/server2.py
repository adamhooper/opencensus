#!/usr/bin/env python2.7

import re

import opencensus_json
import db
from coord import Coord
from tile import Tile

_URL_REGEX = re.compile('^/tiles/(?P<zoom_level>\d\d*)/(?P<column>\d\d*)/(?P<row>\d\d*)\.(?:geo)?json$')

_REGION_ID_REGEX = re.compile('"region_id":(\d+)')

def _get_region_statistics(cursor, region_ids):
    if len(region_ids) == 0: return {}

    cursor.execute("""
        SELECT
            v.region_id, i.name, i.value_type, v.value_integer, v.value_float, v.value_string, v.note
        FROM indicator_region_values v
        INNER JOIN indicators i ON v.indicator_id = i.id
        WHERE v.region_id IN %s
        """, (tuple(region_ids),))

    ret = {}
    for region_id in region_ids:
        ret[region_id] = {}

    for row in cursor:
        (region_id, indicator_name, value_type, value_integer, value_float, value_string, note) = row
        value = None
        if value_type == 'integer':
            value = value_integer
        elif value_type == 'float':
            value = value_float
        elif value_type == 'string':
            value = value_string

        region_statistics = ret[region_id]
        stat = region_statistics[indicator_name] = { 'value': value }
        if note:
            stat['note'] = note

    return ret

def _get_tile_data(zoom_level, row, column):
    cursor = db.connect().cursor()

    cursor.execute("""
        SELECT tile_data FROM tiles WHERE zoom_level = %s AND tile_row = %s AND tile_column = %s
        """, (zoom_level, row, column))

    result = cursor.fetchone()
    if not result: return None

    raw_json = result[0]

    region_id_strings = _REGION_ID_REGEX.findall(raw_json)
    region_ids = map(int, region_id_strings)

    statistics = _get_region_statistics(cursor, region_ids)
    json = _REGION_ID_REGEX.sub(lambda m: '"statistics":%s' % (opencensus_json.encode(statistics[int(m.group(1))]),), raw_json)

    return json

def application(env, start_response):
    url_match = _URL_REGEX.match(env['PATH_INFO'])

    if not url_match:
        start_response('404 Not Found', [('Content-Type', 'text/plain')])
        return ['Invalid URL %s. Should be "/tiles/<zoom_level>/<column>/<row>.json"' % (env['PATH_INFO'],)]

    zoom_level = int(url_match.group('zoom_level'))
    row = int(url_match.group('row'))
    column = int(url_match.group('column'))

    ustring = _get_tile_data(zoom_level, row, column)

    if ustring is None:
        start_response('400 Not Found', [
            ('Content-Type', 'text/plain'),
            ('Access-Control-Allow-Origin', '*')
        ])
        return ['Tile not found']

    utf8string = ustring.encode('utf-8')

    start_response('200 OK', [
        ('Content-Type', 'application/json;charset=UTF-8'),
        ('Content-Length', str(len(utf8string))),
        ('Access-Control-Allow-Origin', '*')
    ])
    return [utf8string]
