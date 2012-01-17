#!/usr/bin/env python

import TileStache
from TileStache.Goodies.Providers.PostGeoJSON import Provider

from db import source_db as _source_db, RealDictCursor as _RealDictCursor
import opencensus_json
from tile import Tile
from tile_renderer import TileRenderer

class _SaveableResponse:
    """Wrapper class against a String (JSON) response that makes it behave like a PIL.Image
    """
    def __init__(self, content):
        self.content = content

    def save(self, out, format):
        if format != 'JSON':
            raise KnownUnknown('PostGeoJSON only saves .json tiles, not "%s"' % format)

        geojson = opencensus_json.encode(self.content)
        out.write(geojson.encode('utf-8'))

class OpenCensusProvider(Provider):
    def __init__(self, layer):
        self.layer = layer

    def getTypeByExtension(self, extension):
        return 'text/json', 'JSON'

    def renderTile(self, width, height, srs, coord):
        cursor = _source_db.cursor(cursor_factory=_RealDictCursor)
        cursor.execute("SET work_mem TO '1024MB'")

        tile = Tile(width, height, coord)
        tileRenderer = TileRenderer(tile, cursor, self.layer.projection)

        tileData = tileRenderer.getTileData()

        return _SaveableResponse(tileData)
