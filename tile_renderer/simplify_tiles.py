#!/usr/bin/env python

import sqlite3
import datetime
import time
import zlib

import opencensus_json

class Tile(object):
    def __init__(self, zoom, row, column):
        self.zoom = int(zoom)
        self.row = int(row)
        self.column = int(column)
        self.string_identifier = '%d/%d/%d' % (self.zoom, self.row, self.column)

    def __hash__(self):
        return hash(self.string_identifier)

    def __cmp__(self, other):
        zoom_cmp = self.zoom - other.zoom
        if zoom_cmp != 0: return zoom_cmp
        row_cmp = self.row - other.row
        if row_cmp != 0: return row_cmp
        return self.column - other.column

    def __eq__(self, other):
        return self.zoom == other.zoom and self.row == other.row and self.column == other.column

    def __str__(self):
        return self.string_identifier

    def children(self):
        return [
            Tile(self.zoom + 1, self.row, self.column),
            Tile(self.zoom + 1, self.row, self.column + 1),
            Tile(self.zoom + 1, self.row + 1, self.column),
            Tile(self.zoom + 1, self.row + 1, self.column + 1)
        ]

class BadTileBin(object):
    def __init__(self):
        self.tiles = set()

    def __contains__(self, tile):
        return tile in self.tiles

    def __iter__(self):
        print 'Converting set to list...'
        tile_list = list(self.tiles)
        print 'Sorting list...'
        tile_list.sort()
        print 'Reversing, so that deleting a partial list will keep the DB consistent...'
        tile_list.reverse()
        print 'Iterating...'
        return iter(tile_list)

    def add(self, tile):
        self.tiles.add(tile)

if __name__ == '__main__':
    import sys

    read_dsn = sys.argv[1]
    write_dsn = sys.argv[2]
    read_db = sqlite3.connect(read_dsn)
    write_db = sqlite3.connect(write_dsn, isolation_level='EXCLUSIVE')
    write_db.text_factory = str
    write_db.execute('PRAGMA journal_mode = TRUNCATE')

    read_cursor = read_db.cursor()
    write_cursor = write_db.cursor()

    write_cursor.execute('CREATE TABLE metadata (name TEXT PRIMARY KEY, value TEXT)')
    read_cursor.execute('SELECT name, value FROM metadata')
    for row in read_cursor:
        write_cursor.execute('INSERT INTO metadata (name, value) VALUES (?, ?)', (row[0], row[1]))
    write_db.commit()

    write_cursor.execute('CREATE TABLE tiles (zoom_level INTEGER, tile_row INTEGER, tile_column INTEGER, tile_data BLOB, PRIMARY KEY (zoom_level, tile_row, tile_column))')

    num_rows = 356067

    q = 'SELECT zoom_level, tile_row, tile_column, tile_data FROM tiles'
    read_cursor.execute(q)

    start_datetime = datetime.datetime.today()

    useless_tiles = BadTileBin()

    for n, row in enumerate(read_cursor):
        t1 = time.time()
        n += 1

        zoom_level, row, column, data = row
        tile = Tile(zoom_level, row, column)

        if tile in useless_tiles:
            print 'Skip %s' % (tile,)
            for child in tile.children(): useless_tiles.add(child)
            continue

        tile_data = opencensus_json.decode(data)

        tile_data.simplify_utfgrids()

        if not tile_data.containsRegionBoundaries():
            for child in tile.children(): useless_tiles.add(child)

        new_json = opencensus_json.encode(tile_data) # slow-ish

        new_json_z = zlib.compress(new_json.encode('utf-8'))

        t2 = time.time()

        write_cursor.execute('INSERT INTO tiles (zoom_level, tile_row, tile_column, tile_data) VALUES (?, ?, ?, ?)', (tile.zoom, tile.row, tile.column, new_json_z))

        t3 = time.time()

        process_time = t2 - t1
        sql_time = t3 - t2
        delta = datetime.datetime.fromtimestamp(t3) - start_datetime

        print 'Done %s.json. Times: (%0.1fms process, %0.1fms sql). %d/%d %0.2f%%, total time %02dd%02dh%02dm%02ds, ' % (
            tile, process_time * 1000, sql_time * 1000,
            n, num_rows, float(n) / num_rows * 100,
            delta.days, delta.seconds / 3600, delta.seconds % 3600 / 60, delta.seconds % 60)

        if n % 100 == 0: write_db.commit()

    write_db.commit()

    print 'Wow. Done!'
