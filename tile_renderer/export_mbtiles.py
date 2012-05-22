#!/usr/bin/env python

# Dumps the "tiles" table into an sqlite3 database

import sqlite3
import zlib

import db

if __name__ == '__main__':
    import sys

    write_dsn = sys.argv[1]

    write_db = sqlite3.connect(write_dsn)

    write_cursor = write_db.cursor()
    write_cursor.execute('PRAGMA synchronous = OFF')

    print 'Creating output database...'
    write_cursor.execute('CREATE TABLE metadata (name VARCHAR(255) NOT NULL, value VARCHAR(255) NOT NULL, PRIMARY KEY (name))')
    write_cursor.execute('CREATE TABLE tiles (zoom_level INTEGER NOT NULL, tile_row INTEGER NOT NULL, tile_column INTEGER NOT NULL, tile_data BLOB NOT NULL, PRIMARY KEY (zoom_level, tile_row, tile_column))')

    print 'Writing metadata...'
    metadata = [
        ('name', 'Statistics Canada Census regions'),
        ('type', 'overlay'),
        ('version', '1'),
        ('description', 'Vector region data used to present 2011 Census results'),
        ('format', 'geojson')
    ]
    write_cursor.executemany('INSERT INTO metadata (name, value) VALUES (?, ?)', metadata)
    write_db.commit()

    print 'Selecting tiles...'
    read_cursor = db.connect().cursor('on_server')
    read_cursor.execute('SELECT * FROM tiles')

    print 'Copying tiles ("." = 10,000 tiles)...',
    for (i, row) in enumerate(read_cursor):
        zoom_level, tile_row, tile_column, json = row
        tile_data = zlib.compress(json.encode('utf-8'))
        write_cursor.execute('INSERT INTO tiles (zoom_level, tile_row, tile_column, tile_data) VALUES (?, ?, ?, ?)', (zoom_level, tile_row, tile_column, buffer(tile_data)))

        if i % 10000 == 9999:
            sys.stdout.write('.')
            sys.stdout.flush()
    print

    print 'Done!'
    write_db.commit()

