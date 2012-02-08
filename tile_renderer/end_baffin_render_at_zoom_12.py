#!/usr/bin/env python

# It takes too long to render the Territories--for too few people.
# (It's callous, but practical.)
# I ran this script when the bottom rows at zoom level 12 were rendering.

import sys
import psycopg2
import zlib
import opencensus_json

db = psycopg2.connect('dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost')
read_c = db.cursor()
write_c = db.cursor()

def remove_child_tiles_from_work_queue(write_c, row, column):
    min_row = row * 2
    max_row = min_row + 1
    min_column = column * 2
    max_column = min_column + 1
    write_c.execute('INSERT INTO work_queue_rejects (zoom_level, tile_row, tile_column) SELECT zoom_level, tile_row, tile_column FROM work_queue WHERE zoom_level = 13 AND tile_row >= %s AND tile_row <= %s AND tile_column >= %s AND tile_column <= %s', (min_row, max_row, min_column, max_column))
    write_c.execute('DELETE FROM work_queue WHERE zoom_level = 13 AND tile_row >= %s AND tile_row <= %s AND tile_column >= %s AND tile_column <= %s', (min_row, max_row, min_column, max_column))

print 'Finding blacklist regions...'
read_c.execute("SELECT type, uid FROM regions WHERE province_uid IN (SELECT uid FROM regions WHERE type = 'Province' AND name IN ('Nunavut', 'Northwest Territories', 'Yukon'))")

blacklist_regions = set()
for (region_type, uid) in read_c:
    blacklist_regions.add('%s-%s' % (region_type, uid))

print 'Nixing tiles that contain any of: %r' % blacklist_regions

print 'Querying zoom-level-12 tiles...'
read_c.execute('SELECT tile_row, tile_column, tile_data FROM tiles WHERE zoom_level = 12')

print 'Iterating. "." for each 100 tiles checked; "!" for each 100 tiles whose children are removed:',
x = 0
for (n, row) in enumerate(read_c):
    (row, column, data_z) = row
    data = zlib.decompress(data_z).decode('utf-8')
    geojson = opencensus_json.decode(data)
    grids = geojson._utfgrids

    breaking = False
    for grid in grids:
        if breaking: break
        for key in grid.keys:
            if key in blacklist_regions:
                remove_child_tiles_from_work_queue(write_c, row, column)
                x += 1
                if x % 100 == 0:
                    sys.stdout.write('!'); sys.stdout.flush()
                    db.commit()
                breaking = True
                break

    if n % 99 == 0:
        sys.stdout.write('.'); sys.stdout.flush()

db.commit()
