#!/usr/bin/env python

from db import source_db

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
