#!/usr/bin/env python

__requires__ = ['ModestMaps==1.3.1', 'psycopg2==2.4.4']
import pkg_resources

import os
from math import pi
import sqlite3
import time
import zlib

import ModestMaps
from ModestMaps.Geo import MercatorProjection, deriveTransformation, Location
from ModestMaps.Core import Coordinate

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)
from psycopg2.extras import RealDictCursor

import opencensus_json
from tile import Tile
from tile_renderer import TileRenderer

class MBTilesCoordQueue(object):
    def __init__(self, db, projection):
        self.db = db
        self.db_cursor = db.cursor()
        self.projection = projection

        # initialize DB
        try:
            self.db_cursor.execute('SELECT * FROM work_queue LIMIT 1')
        except sqlite3.OperationalError:
            self.initializeDatabase()

        (self.nw, self.se) = self._queryBounds()

    def initializeDatabase(self):
        self.db_cursor.execute('CREATE TABLE work_queue (zoom_level INTEGER NOT NULL, tile_row INTEGER NOT NULL, tile_column INTEGER NOT NULL, worker INTEGER, PRIMARY KEY (zoom_level, tile_row, tile_column))')
        self.db_cursor.execute('CREATE INDEX work_queue_workers ON work_queue (worker)')

        self.db_cursor.execute('INSERT OR REPLACE INTO work_queue (zoom_level, tile_column, tile_row, worker) VALUES (0, 0, 0, NULL)')
        self.db.commit()

    def _queryBounds(self):
        self.db_cursor.execute("SELECT value FROM metadata WHERE name = 'bounds'")
        row = self.db_cursor.fetchone()
        if row is None: return None

        numbers = map(float, row[0].split(','))
        nw = Location(numbers[3], numbers[0])
        se = Location(numbers[1], numbers[2])
        return (nw, se)

    def getWorkerId(self):
        return os.getpid()

    def getPreviouslyReservedCoord(self):
        self.db_cursor.execute('SELECT zoom_level, tile_row, tile_column FROM work_queue WHERE worker = ?', (self.getWorkerId(),))
        row = self.db_cursor.fetchone()

        if row is None: return None

        (zoom, row, column) = row
        coord = Coordinate(row, column, zoom)
        return coord

    def get(self):
        ret = self.getPreviouslyReservedCoord()

        if ret is None:
            self.db_cursor.execute('SELECT zoom_level, tile_row, tile_column FROM work_queue WHERE worker IS NULL ORDER BY zoom_level, tile_row, tile_column LIMIT 1')
            row = self.db_cursor.fetchone()
            (zoom_level, tile_row, tile_column) = row
            self.db_cursor.execute('UPDATE work_queue SET worker = ? WHERE worker IS NULL AND zoom_level = ? AND tile_row = ? AND tile_column = ?', (self.getWorkerId(), zoom_level, tile_row, tile_column))
            self.db.commit()

            ret = self.getPreviouslyReservedCoord()

        return ret

    def unreserveCoords(self):
        self.db_cursor.execute('UPDATE work_queue SET worker = NULL WHERE worker = ?', (self.getWorkerId(),))
        self.db.commit()

    def enumerateCoordChildren(self, coord):
        zoomed_coord = coord.zoomBy(1)

        nw_coord = self.projection.locationCoordinate(self.nw).zoomTo(zoomed_coord.zoom).container()
        se_coord = self.projection.locationCoordinate(self.se).zoomTo(zoomed_coord.zoom).container()

        possible_coords = (zoomed_coord, zoomed_coord.right(), zoomed_coord.down(), zoomed_coord.right().down())
        for possible_coord in possible_coords:
            if possible_coord.row >= nw_coord.row and possible_coord.column >= nw_coord.column and possible_coord.row <= se_coord.row and possible_coord.column <= se_coord.column:
                yield possible_coord

    def queueCoordChildren(self, coord):
        for child_coord in self.enumerateCoordChildren(coord):
            self.db_cursor.execute('INSERT OR REPLACE INTO work_queue (zoom_level, tile_column, tile_row, worker) VALUES (?, ?, ?, NULL)', (child_coord.zoom, child_coord.column, child_coord.row))
        self.db.commit()

    def markCoordFinished(self, coord):
        self.db_cursor.execute('DELETE FROM work_queue WHERE zoom_level = ? AND tile_column = ? AND tile_row = ? AND worker = ?', (coord.zoom, coord.column, coord.row, self.getWorkerId()))
        self.db.commit()

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

        try:
            self.destination_db_cursor.execute('SELECT 1 FROM metadata')
        except sqlite3.OperationalError:
            self.initializeDatabase()

        self.destination_db_cursor.execute('SELECT COUNT(*) FROM metadata WHERE name = ?', ('bounds',))
        if self.destination_db_cursor.fetchone()[0] == 0:
            (nw, se) = self._calculateBounds()
            bounds_str = ','.join([str(nw.lon), str(se.lat), str(se.lon), str(nw.lat)])
            self.destination_db_cursor.execute('INSERT OR REPLACE INTO metadata (name, value) VALUES (?, ?)', ('bounds', bounds_str))
            self.destination_db.commit()


    def initializeDatabase(self):
        self.destination_db_cursor.execute('CREATE TABLE metadata (name text PRIMARY KEY, value text)')
        for keyval in (
                ('name', 'OpenCensus'),
                ('type', 'overlay'),
                ('version', '1'),
                ('description', 'Statistics Canada census regions'),
                ('format', 'geojson')
                ):
            self.destination_db_cursor.execute('INSERT OR REPLACE INTO metadata (name, value) VALUES (?, ?)', keyval)

        self.destination_db_cursor.execute('CREATE TABLE tiles (zoom_level INTEGER NOT NULL, tile_row INTEGER NOT NULL, tile_column INTEGER NOT NULL, tile_data blob, PRIMARY KEY (zoom_level, tile_row, tile_column))')

        self.destination_db.commit()

    def _calculateBounds(self):
        self.source_db_cursor.execute('SELECT MIN(min_longitude) AS nw_longitude, MAX(max_latitude) AS nw_latitude, MAX(max_longitude) AS se_longitude, MIN(min_latitude) AS se_latitude FROM region_polygons')
        row = self.source_db_cursor.fetchone()
        nw = Location(row['nw_latitude'], row['nw_longitude'])
        se = Location(row['se_latitude'], row['se_longitude'])
        return (nw, se)

    def work(self, progress_callback=None):
        queue = MBTilesCoordQueue(self.destination_db, self.projection)

        try:
            while True:
                t1 = time.time()

                coord = queue.get()
                tile = Tile(self.tile_width, self.tile_height, coord)
                renderer = TileRenderer(tile, self.source_db_cursor, self.projection, include_statistics=False)
                tile_data = renderer.getTileData()

                geojson = opencensus_json.encode(tile_data)
                geojson_z = zlib.compress(geojson.encode('utf-8'))

                self.destination_db_cursor.execute(
                    'INSERT OR REPLACE INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?, ?, ?, ?)',
                    (tile.zoom, tile.column, tile.row, buffer(geojson_z)))
                self.destination_db.commit()

                if tile_data.containsRegionBoundaries():
                  queue.queueCoordChildren(coord)

                queue.markCoordFinished(coord)

                if progress_callback is not None:
                    t2 = time.time()
                    tdiff = t2 - t1
                    progress_callback(tile, tdiff)
        finally:
            queue.unreserveCoords()

if __name__ == '__main__':
    import sys

    source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'
    destination_dsn = sys.argv[1]

    source_db = psycopg2.connect(source_dsn)
    destination_db = sqlite3.connect(destination_dsn)
    destination_db.text_factory = str

    renderer = MBTilesRenderer(256, 256, source_db, destination_db)

    def progress_callback(tile, delay):
        sys.stderr.write('/%d/%d/%d.geojson (%0.1fms)\n' % (tile.zoom, tile.row, tile.column, delay))

    renderer.work(progress_callback=progress_callback)
