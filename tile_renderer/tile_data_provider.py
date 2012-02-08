#!/usr/bin/env python

import sqlite3
import zlib

import TileStache
from TileStache.Goodies.Providers.PostGeoJSON import Provider

from db import source_db as _source_db, RealDictCursor as _RealDictCursor
import opencensus_json
from tile import Tile
from tile_renderer import TileRenderer

_statistics_db = sqlite3.connect('statistics.sqlite3')
_statistics_cursor = _statistics_db.cursor()
# Returns a hash of { region_id: stats dict }
def getStatistics(region_ids):
    q = 'SELECT region_id, statistics FROM region_statistics WHERE region_id IN (%s)' % (','.join(map(str, region_ids)),)
    _statistics_cursor.execute(q)

    ret = {}

    for region_id, statistics_z in _statistics_cursor:
        u = zlib.decompress(statistics_z).decode('utf-8')
        statistics = opencensus_json.decode(u)

        ret[region_id] = statistics

    return ret

class _SaveableTileData:
    """Wrapper class against a TileData response that makes it behave like a PIL.Image
    """
    def __init__(self, tile_data):
        self.tile_data = tile_data

    def save(self, out, format):
        geojson = opencensus_json.encode(self.content)
        out.write(geojson.encode('utf-8'))

class _SaveableUnicode:
    """Wrapper class against a Unicode string that makes it behave like a PIL.Image
    """
    def __init__(self, ustring):
        self.ustring = ustring

    def save(self, out, format):
        out.write(self.ustring.encode('utf-8'))

class OpenCensusProvider(Provider):
    def __init__(self, layer):
        self.layer = layer

    def getTypeByExtension(self, extension):
        return 'text/json', 'JSON'

    def renderTileFromTilesTables(self, coord, cursor):
        cursor.execute('SELECT tile_data FROM tiles WHERE zoom_level = %s AND tile_row = %s AND tile_column = %s', (coord.zoom, coord.row, coord.column))
        row = cursor.fetchone()

        if row is not None:
            u = zlib.decompress(row['tile_data']).decode('utf-8')
            data = opencensus_json.decode(u)

            regions = {}

            for feature in data.features:
                if 'statistics' in feature['properties']:
                    properties = feature['properties']
                    statistics = properties['statistics']
                    if '0' in statistics:
                        region_id = statistics['0']['TO-FILL']['value']
                        regions[region_id] = properties

            if len(regions) > 0:
                region_to_statistics = getStatistics(regions.keys())
                for region_id, statistics in region_to_statistics.items():
                    regions[region_id]['statistics'] = statistics

            ustring = opencensus_json.encode(data)
            return _SaveableUnicode(ustring)

        else:
            return _SaveableUnicode('')

    def renderTile(self, width, height, srs, coord):
        cursor = _source_db.cursor(cursor_factory=_RealDictCursor)
        cursor.execute("SET work_mem TO '1024MB'")

        u = self.renderTileFromTilesTables(coord, cursor)
        if u is not None: return u

        tile = Tile(width, height, coord)
        tileRenderer = TileRenderer(tile, cursor, self.layer.projection)

        tileData = tileRenderer.getTileData()

        return _SaveableTileData(tileData)
