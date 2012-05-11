#!/usr/bin/env python2.7

import re

import opencensus_json
import db
from coord import Coord
from tile import Tile
from tile_data import TileData

_URL_REGEX = re.compile('^/tiles/(?P<zoom_level>\d\d*)/(?P<column>\d\d*)/(?P<row>\d\d*)\.(?:geo)?json$')

def _get_region_statistics(cursor, region_ids):
    if len(region_ids) == 0: return {}

    cursor.execute("""
        SELECT
            v.region_id, i.name, v.year, i.value_type, v.value_integer, v.value_float, v.note
        FROM indicator_region_values v
        INNER JOIN indicators i ON v.indicator_id = i.id
        WHERE v.region_id IN %s
        """, (tuple(region_ids),))

    ret = {}

    for row in cursor:
        (region_id, indicator_name, year, value_type, value_integer, value_float, note) = row
        value = None
        if value_type == 'integer':
            value = value_integer
        elif value_type == 'float':
            value = value_float

        if region_id not in ret:
            ret[region_id] = []

        ret[region_id].append({
            'year': year,
            'name': indicator_name,
            'value': value,
            'note': note,
        })

    return ret

def _get_tile_data(zoom_level, row, column):
    cursor = db.connect().cursor()

    cursor.execute("""
        SELECT
            r.id, r.uid, r.type, r.name, rps.parents,
            ST_AsGeoJSON(ST_Collect(ST_Transform(ST_SetSRID(rpt.geometry_srid3857, 3857), 4326))) AS geojson,
            ST_AsSVG(ST_Collect(rpt.geometry_srid3857)) AS svg
        FROM region_polygon_tiles rpt
        INNER JOIN region_polygons_metadata rpm ON rpt.region_polygon_id = rpm.region_polygon_id
        INNER JOIN regions r ON rpm.region_id = r.id
        INNER JOIN region_parents_strings rps ON r.id = rps.region_id
        WHERE rpt.zoom_level = %s AND rpt.tile_row = %s AND rpt.tile_column = %s
        GROUP BY r.id, r.position, r.type, r.name, rps.parents
        ORDER BY r.position
        """, (zoom_level, row, column))

    coord = Coord(row, column, zoom_level)
    tile = Tile(256, 256, coord)
    tile_data = TileData(render_utfgrid_for_tile=tile)

    region_id_to_json_id = {}

    for row in cursor:
        (region_id, region_uid, region_type, region_name, region_parents, region_geojson, region_svg) = row
        region_json_id = '%s-%s' % (region_type, region_uid)

        if not region_parents or not len(region_parents):
            region_parents = []
        else:
            region_parents = region_parents.split(',')

        properties = {
            'name': region_name,
            'type': region_type,
            'uid': region_uid,
            'parents': region_parents,
        }

        tile_data.addRegion(region_json_id, properties, region_geojson, region_svg)
        region_id_to_json_id[region_id] = region_json_id

    region_statistics = _get_region_statistics(cursor, region_id_to_json_id.keys())

    for region_id, one_region_statistics in region_statistics.items():
        json_id = region_id_to_json_id[region_id]
        for x in one_region_statistics:
            tile_data.addRegionStatistic(json_id, x['year'], x['name'], x['value'], x['note'])

    return tile_data

def application(env, start_response):
    url_match = _URL_REGEX.match(env['PATH_INFO'])

    if not url_match:
        start_response('404 Not Found', [('Content-Type', 'text/plain')])
        return ['Invalid URL %s. Should be "/tiles/<zoom_level>/<column>/<row>.json"' % (env['PATH_INFO'],)]

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

    ustring = opencensus_json.encode(tile_data)
    utf8string = ustring.encode('utf-8')

    start_response('200 OK', [
        ('Content-Type', 'application/json;charset=UTF-8'),
        ('Content-Length', str(len(utf8string))),
        ('Access-Control-Allow-Origin', '*')
    ])
    return [utf8string]
