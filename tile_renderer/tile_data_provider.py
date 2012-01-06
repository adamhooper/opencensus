#!/usr/bin/env python

__requires__ = ['TileStache==1.19.4', 'psycopg2==2.4.3', 'shapely==1.2.13']
import pkg_resources

import TileStache
from TileStache.Goodies.Providers.PostGeoJSON import Provider

from tile import Tile
from tile_renderer import TileRenderer

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)
from psycopg2.extras import RealDictCursor

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

    def getTypeByExtension(self, extension):
        return 'text/json', 'JSON'

    def renderTile(self, width, height, srs, coord):
        db = psycopg2.connect(self.dbdsn).cursor(cursor_factory=RealDictCursor)
        db.execute("SET work_mem TO '1024MB'")

        tile = Tile(width, height, coord)
        tileRenderer = TileRenderer(tile, db, self.layer.projection)

        s = tileRenderer.getTileData()

        db.close()

        return _SaveableResponse(s)
