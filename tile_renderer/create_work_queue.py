#!/usr/bin/env python

# Inserts all the tiles left to be coded into work_queue.
# In other words, you may, at any time, DELETE FROM work_queue
# and then run this script. You won't lose any data.

import sys
import sqlite3
import zlib

import psycopg2

import opencensus_json

db = sqlite3.connect('mbtiles.sqlite3-without-work-queue')
c = db.cursor()
write_db = psycopg2.connect('dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost')
write_c = write_db.cursor()

print 'Querying tiles...'

c.execute('SELECT zoom_level, tile_row, tile_column, tile_data FROM tiles ORDER BY zoom_level DESC, tile_row DESC, tile_column DESC')

print 'Populating in-memory queue with children. "." means 1,000 children: '

queue_tiles = []

parent = None

n = 0
for (i, row) in enumerate(c):
    zoom_level, row, column, data = row

    if i == 0:
        parent = (zoom_level - 1, row / 2, column / 2)
    else:
        if zoom_level == parent[0] and row == parent[1] and column < parent[2]:
            break

    tile_data = opencensus_json.decode(zlib.decompress(data).decode('utf-8'))
    if tile_data.containsRegionBoundaries():
        queue_tiles.append((zoom_level + 1, row * 2 + 1, column * 2 + 1))
        queue_tiles.append((zoom_level + 1, row * 2 + 1, column * 2))
        queue_tiles.append((zoom_level + 1, row * 2, column * 2 + 1))
        queue_tiles.append((zoom_level + 1, row * 2, column * 2))
        n += 4

        if n % 1000 == 0:
            sys.stdout.write('.')
            sys.stdout.flush()

print
print 'Final parent: %r' % (parent,)
print 'Reversing queue...'

queue_tiles.reverse()

print '%d tiles to insert' % (len(queue_tiles),)
print 'First tile: %r' % (queue_tiles[0],)
print 'Last tile: %r' % (queue_tiles[-1],)

print 'Inserting into queue. "." means 1,000 children: '

q = 'INSERT INTO work_queue(zoom_level, tile_row, tile_column, worker) VALUES (%s, %s, %s, NULL)'
for n, values in enumerate(queue_tiles):
    write_c.execute(q, values)
    if n % 1000 == 0:
        write_db.commit()
        sys.stdout.write('.')
        sys.stdout.flush()

write_db.commit()

print
