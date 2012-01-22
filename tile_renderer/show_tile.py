#!/usr/bin/env python

import zlib
import opencensus_json

from db import source_db

def fetch_tile_data(cursor, zoom_level, row, column):
    cursor.execute('SELECT tile_data FROM tiles WHERE zoom_level = %s AND tile_row = %s AND tile_column = %s', (zoom_level, row, column))
    row = c.fetchone()
    if row is None: return None
    data_z = row[0]
    data = zlib.decompress(data_z)
    tile_data = opencensus_json.decode(data)
    return tile_data

if __name__ == '__main__':
    import sys

    if len(sys.argv) != 4:
        sys.stderr.write('Usage: %s zoom_level row column\n' % (sys.argv[0],))
        sys.exit(1)

    zoom_level, row, column = map(int, sys.argv[1:])

    c = source_db.cursor()

    tile_data = fetch_tile_data(c, zoom_level, row, column)

    if tile_data is None:
        sys.stderr.write('Could not find tile %d/%d/%d\n' % (zoom_level, row, column))
        sys.exit(1)

    for feature in tile_data.features:
        print 'Feature %s -- %r -- %r' % (feature['id'], feature['properties'], feature['geometry'])

    for grid in tile_data.utfgrids():
        print 'Grid with keys %r:' % (grid.keys)
        print '\n'.join(grid.grid)
