#!/usr/bin/env python

from db import source_db
import show_tile

c = source_db.cursor()

c.execute('SELECT MAX(zoom_level) FROM work_queue')
next_zoom_level = c.fetchone()[0]
zoom_level = next_zoom_level - 1

c.execute('SELECT COUNT(*) FROM tiles WHERE zoom_level = %s', (zoom_level,))
zoom_level_tiles = c.fetchone()[0]
c.execute('SELECT COUNT(*) FROM work_queue WHERE zoom_level = %s', (zoom_level,))
zoom_level_todo = c.fetchone()[0]
c.execute('SELECT COUNT(*) FROM work_queue WHERE zoom_level = %s', (next_zoom_level,))
next_zoom_level_todo = c.fetchone()[0]

print 'Rendered %d of %d tiles at zoom level %d (%0.2f%%)' % (zoom_level_tiles, zoom_level_tiles + zoom_level_todo, zoom_level, (1.0 * zoom_level_tiles / (zoom_level_tiles + zoom_level_todo) * 100))
print 'Queued %d at zoom level %d' % (next_zoom_level_todo, next_zoom_level)

c.execute('SELECT zoom_level, tile_row, tile_column FROM tiles ORDER BY zoom_level DESC, tile_row DESC, tile_column DESC LIMIT 1')
zoom, row, column = c.fetchone()

print 'Last tile: %d/%d/%d' % (zoom, row, column)

tile_data = show_tile.fetch_tile_data(c, zoom, row, column)

feature_descriptions = [(feature['id'], feature['properties']['name']) for feature in tile_data.features]

print 'Last tile regions: %r' % feature_descriptions

non_block_keys = set()
for grid in tile_data.utfgrids():
    for key in grid.keys:
        if len(key) > 0 and not key.startswith('DisseminationBlock-') and not key.startswith('ElectoralDistrict-'):
            non_block_keys.add(key)

print 'Last tile region non-final keys: %r' % (non_block_keys,)
