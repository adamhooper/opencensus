#!/usr/bin/env python2.7

import os as _os
from time import time as _time
from sys import stderr as _logger

from region_polygon_at_zoom_level import RegionPolygonAtZoomLevel as _RegionPolygonAtZoomLevel

class WorkQueueRenderer:
    def __init__(self, pixels_per_tile_side, db):
        self.pixels_per_tile_side = pixels_per_tile_side
        self.db = db
        self.cursor = db.cursor()
        self.done = False

    def get_worker_id(self):
        return _os.getpid()

    def _get_task_reserved_by_this_worker(self):
        worker_id = self.get_worker_id()
        self.cursor.execute('SELECT zoom_level, region_polygon_id FROM work_queue WHERE worker = %s', (worker_id,))
        row = self.cursor.fetchone()

        return row

    def set_done_if_done(self):
        self.cursor.execute('SELECT zoom_level FROM work_queue LIMIT 1')
        row = self.cursor.fetchone()

        if row is None:
            self.done = True

    def reserve_task(self):
        worker_id = self.get_worker_id()
        ret = self._get_task_reserved_by_this_worker()
        attempt = 0

        while ret is None:
            attempt += 1

            if attempt >= 5:
                self.set_done_if_done()
                if self.done:
                    break

            self.cursor.execute('''
                UPDATE work_queue
                SET worker = %s
                WHERE worker IS NULL
                  AND (zoom_level, region_polygon_id) = (
                    SELECT zoom_level, region_polygon_id
                    FROM work_queue
                    WHERE worker IS NULL
                    ORDER BY zoom_level, region_polygon_id
                    LIMIT 1)
                RETURNING zoom_level, region_polygon_id''', (worker_id,))
            self.db.commit()
            ret = self.cursor.fetchone()

        return ret

    def unreserve_tasks(self):
        worker_id = self.get_worker_id()
        self.cursor.execute(
                'UPDATE work_queue SET worker = NULL WHERE worker = %s',
                (worker_id,))
        self.db.commit()

    def mark_task_finished(self, task):
        worker_id = self.get_worker_id()
        zoom_level, region_polygon_id = task
        self.cursor.execute('''
            DELETE FROM work_queue
            WHERE worker = %s
              AND zoom_level = %s
              AND region_polygon_id = %s
            ''', (worker_id, zoom_level, region_polygon_id))
        self.db.commit()

    def process_task(self, task):
        zoom_level, region_polygon_id = task

        self.cursor.execute('''
            SELECT ST_AsBinary(polygon_srid3857)
            FROM region_polygons_zoom%d
            WHERE region_polygon_id = %s
            ''' % (zoom_level, '%s'), (region_polygon_id,))

        wkb = str(self.cursor.fetchone()[0])

        rpzl = _RegionPolygonAtZoomLevel(
                self.pixels_per_tile_side, zoom_level, wkb)

        _logger.write('Starting %d (zoom %d)...\n' % (region_polygon_id, zoom_level))

        for row, column, slice_wkb in rpzl.get_tile_slices():
            slice_binary = memoryview(slice_wkb)

            self.cursor.execute('''
                INSERT INTO region_polygon_tiles (region_polygon_id, zoom_level, tile_row, tile_column, geometry_srid3857)
                VALUES (%s, %s, %s, %s, ST_SetSRID(ST_GeomFromWKB(%s), 3857))
                ''',
                (region_polygon_id, zoom_level, row, column, slice_binary))
        # don't commit--we do that when we adjust the work_queue table

    def work(self):
        try:
            while not self.done:
                t1 = _time()
                task = self.reserve_task()
                if self.done: break
                t2 = _time()
                self.process_task(task)
                t3 = _time()
                self.mark_task_finished(task)
                t4 = _time()

                _logger.write(
                    'done %d: q1 %0.1fms, process %0.1fms, q2 %0.1fms\n' % (
                        task[1],
                        (t2 - t1) * 1000,
                        (t3 - t2) * 1000,
                        (t4 - t3) * 1000))

        finally:
            self.db.rollback()
            self.unreserve_tasks()

def main():
    from db import source_db as db

    renderer = WorkQueueRenderer(256, db)
    renderer.work()

if __name__ == '__main__':
    from multiprocessing import Process
    NUM_PROCESSES = 4

    processes = [ Process(target=main) for x in xrange(0, NUM_PROCESSES) ]
    map(lambda p: p.start(), processes)
    map(lambda p: p.join(), processes)
