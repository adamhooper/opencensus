#!/usr/bin/env python

__requires__ = ['ModestMaps==1.3.1', 'psycopg2==2.4.4']
import pkg_resources

from math import pi
import sqlite3
import time

import ModestMaps
from ModestMaps.Geo import MercatorProjection, deriveTransformation, Location
from ModestMaps.Core import Coordinate

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)
from psycopg2.extras import RealDictCursor

from tile import Tile
from tile_renderer import TileRenderer

class MBTilesRenderer(object):
    def __init__(self, tile_width, tile_height, source_db, destination_db):
        self.tile_width = tile_width
        self.tile_height = tile_height

        t = deriveTransformation(-pi, pi, 0, 0, pi, pi, 1, 0, -pi, -pi, 0, 1)
        self.projection = MercatorProjection(0, t)

        self.source_db = source_db
        self.source_db_cursor = source_db.cursor(cursor_factory=RealDictCursor)
        self.destination_db = destination_db
        self.destination_db_cursor = destination_db.cursor()

        (self.nw, self.se) = self._calculateBounds()

        bounds_str = ','.join([str(self.nw.lon), str(self.se.lat), str(self.se.lon), str(self.nw.lat)])

        self.destination_db_cursor.execute(
                'INSERT INTO metadata (name, value) VALUES (?, ?)',
                ('bounds', bounds_str))
        self.destination_db.commit()

    def _calculateBounds(self):
        self.source_db_cursor.execute('SELECT MIN(min_longitude) AS nw_longitude, MAX(max_latitude) AS nw_latitude, MAX(max_longitude) AS se_longitude, MIN(min_latitude) AS se_latitude FROM region_polygons')
        row = self.source_db_cursor.fetchone()
        nw = Location(row['nw_latitude'], row['nw_longitude'])
        se = Location(row['se_latitude'], row['se_longitude'])
        return (nw, se)

    def enumerateTilesAtZoom(self, zoom):
        coord1 = self.projection.locationCoordinate(self.nw).zoomTo(zoom).container()
        coord2 = self.projection.locationCoordinate(self.se).zoomTo(zoom).container()

        sys.stderr.write('Projection: %r\n' % (self.projection,))
        sys.stderr.write('Coords: %r, %r\n' % (coord1, coord2))

        for row in xrange(int(coord1.row), int(coord2.row) + 1):
            for column in xrange(int(coord1.column), int(coord2.column) + 1):
                coord = Coordinate(row, column, zoom)
                yield Tile(self.tile_width, self.tile_height, coord)

    def _calculateTileData(self, tile):
        renderer = TileRenderer(tile, self.source_db_cursor, self.projection, include_statistics=False)
        return renderer.getTileData()

    def _saveTileData(self, tile, data):
        self.destination_db_cursor.execute(
            'INSERT INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)',
            (tile.zoom, tile.column, tile.row, data))
        self.destination_db.commit()

    def renderAtZoom(self, zoom, progress_callback=None):
        for tile in self.enumerateTilesAtZoom(zoom):
            t1 = time.time()
            data = self._calculateTileData(tile)
            self._saveTileData(tile, data)
            t2 = time.time()
            if progress_callback is not None: progress_callback(tile, t2 - t1)

if __name__ == '__main__':
    import sys

    source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'
    destination_dsn = sys.argv[1]

    source_db = psycopg2.connect(source_dsn)
    destination_db = sqlite3.connect(destination_dsn)
    destination_db_cursor = destination_db.cursor()

    destination_db_cursor.execute('CREATE TABLE metadata (name text, value text)')
    for keyval in (
            ('name', 'OpenCensus'),
            ('type', 'overlay'),
            ('version', '1'),
            ('description', 'Statistics Canada census regions'),
            ('format', 'geojson')
            ):
        destination_db_cursor.execute('INSERT INTO metadata (name, value) VALUES (?, ?)', keyval)

    destination_db_cursor.execute('CREATE TABLE tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob)')
    destination_db_cursor.execute('CREATE UNIQUE INDEX tiles_index ON tiles (zoom_level, tile_row, tile_column)')

    destination_db.commit()

    renderer = MBTilesRenderer(256, 256, source_db, destination_db)

    def progress_callback(tile, delay):
        sys.stderr.write('/%d/%d/%d.geojson (%0.2fs)\n' % (tile.zoom, tile.row, tile.column, delay))

    for zoom in xrange(3, 14):
        renderer.renderAtZoom(zoom, progress_callback=progress_callback)
