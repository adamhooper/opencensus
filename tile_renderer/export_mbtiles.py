#!/usr/bin/env python

# Outputs the "tiles" table as an sqlite3-compatible series of SQL commands

import sys
import zlib
# Import psycopg2 directly, so we don't cast utf-8 strings to unicode and back
import psycopg2

source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'

if __name__ == '__main__':
    print 'PRAGMA synchronous = OFF;'

    print >> sys.stderr, 'Creating output database...'

    print 'CREATE TABLE metadata (name VARCHAR(255) NOT NULL, value VARCHAR(255) NOT NULL, PRIMARY KEY (name));'
    print 'CREATE TABLE tiles (zoom_level INTEGER NOT NULL, tile_row INTEGER NOT NULL, tile_column INTEGER NOT NULL, tile_data BLOB NOT NULL, PRIMARY KEY (zoom_level, tile_row, tile_column));'

    print >> sys.stderr, 'Writing metadata...'
    metadata = [
        ('name', 'Statistics Canada Census regions'),
        ('type', 'overlay'),
        ('version', '1'),
        ('description', 'Vector region data used to present 2011 Census results'),
        ('format', 'geojson')
    ]
    for key, val in metadata:
        print "INSERT INTO metadata (name, value) VALUES ('%s', '%s');" % (key, val)

    print >> sys.stderr, 'Selecting tiles...'
    connection = psycopg2.connect(source_dsn)
    connection.set_client_encoding('UTF-8')
    read_cursor = connection.cursor('on_server')
    read_cursor.execute('SELECT * FROM tiles ORDER BY zoom_level, tile_row, tile_column')

    print >> sys.stderr, 'Dumping tiles... ("." = 1,000 tiles)',
    while True:
        rows = read_cursor.fetchmany(1000)
        if len(rows) == 0: break

        for (zoom_level, tile_row, tile_column, json_data) in rows:
            tile_data = zlib.compress(json_data)
            tile_data_hex = tile_data.encode('hex')

            print "INSERT INTO tiles (zoom_level, tile_row, tile_column, tile_data) VALUES (%d, %d, %d, X'%s');" % (zoom_level, tile_row, tile_column, tile_data_hex)

        sys.stderr.write('.')
        sys.stderr.flush()
    print >> sys.stderr

    print >> sys.stderr, 'Done!'
