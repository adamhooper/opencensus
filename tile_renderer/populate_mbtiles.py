#!/usr/bin/env python

# Dumps the "tiles" table into an sqlite3 database
#
# DO NOT USE THIS! It takes too much memory. Instead,
# just pg_dump as SQL, convert "'\x" to "x'" (that's the
# ANSI BLOB starter) and run the resulting file as an
# SQLite script--starting with the VERY important SQL,
# "PRAGMA synchronous = OFF"

__requires__ = ['psycopg2==2.4.4']
import pkg_resources

import sqlite3

from db import source_db

import opencensus_json

if __name__ == '__main__':
    import sys

    write_dsn = sys.argv[1]

    write_db = sqlite3.connect(write_dsn)

    read_cursor = source_db.cursor()
    write_cursor = write_db.cursor()
    write_cursor.execute('PRAGMA synchronous = OFF')

    print 'Creating output database...'
    write_cursor.execute('CREATE TABLE metadata (name VARCHAR(255) NOT NULL, value VARCHAR(255) NOT NULL, PRIMARY KEY (name))')
    write_cursor.execute('CREATE TABLE tiles (zoom_level INTEGER NOT NULL, tile_row INTEGER NOT NULL, tile_column INTEGER NOT NULL, tile_data BLOB NOT NULL, PRIMARY KEY (zoom_level, tile_row, tile_column))')

    print 'Copying metadata...'
    read_cursor.execute('SELECT name, value FROM metadata')
    for row in read_cursor:
      write_cursor.execute('INSERT INTO metadata (name, value) VALUES (?, ?)', row)
    write_db.commit()

    print 'Selecting tiles...'
    read_cursor.execute('SELECT * FROM tiles')

    print 'Copying tiles ("." = 10,000 tiles)...',
    for (row, i) in enumerate(read_cursor):
      write_cursor.execute('INSERT INTO tiles (zoom_level, tile_row, tile_column, tile_data) VALUES (?, ?, ?, ?)', row)
      if i % 10000 == 9999:
        sys.stdout.write('.')
        sys.stdout.flush()
    print

    print 'Done!'
    write_db.commit()

