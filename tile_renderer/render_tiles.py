#!/usr/bin/env python2.7

from work_queue import WorkQueue as _WorkQueue

def create_worker(db):
    cursor = db.cursor()

    cursor.execute('''
        PREPARE render_tile (INT, INT, INT) AS
        INSERT INTO tiles (zoom_level, tile_row, tile_column, tile_data)
        SELECT $1, $2, $3, CONCAT(
            '{"crs":{"type":"name","properties":{"name":"urn:org:def:crs:EPSG:3857"}},"type":"FeatureCollection","features":[',
            (
                SELECT STRING_AGG(x.feature_json, ',')
                FROM (
                    SELECT CONCAT(
                        '{"type":"Feature","id":"', ft.json_id, '","properties":{"region_id":', ft.region_id, ',"name":"', REPLACE(COALESCE(ft.region_name, ''), '"', '\"'), '","parents":', rpj.parents_json, '},"geometry":', ft.geojson_geometry, '}') AS feature_json
                    FROM feature_tiles ft
                    INNER JOIN region_parents_json rpj ON ft.region_id = rpj.region_id
                    WHERE zoom_level = $1 AND tile_row = $2 AND tile_column = $3
                    ORDER BY ft.position) x
            ), '],"utfgrids":',
            (SELECT utfgrids FROM utfgrids WHERE zoom_level = $1 AND tile_row = $2 AND tile_column = $3), '}')
            ''')

    def worker(zoom_level, tile_row, tile_column):
        cursor.execute('EXECUTE render_tile (%s, %s, %s)', (zoom_level, tile_row, tile_column))

    return worker

def main():
    import db
    source_db = db.connect()

    worker = create_worker(source_db)
    work_queue = _WorkQueue(source_db, 'work_queue3', [ 'zoom_level', 'tile_row', 'tile_column' ], worker)
    work_queue.work()

if __name__ == '__main__':
    from multiprocessing import Process, cpu_count
    num_processes = cpu_count()

    processes = [ Process(target=main) for x in xrange(0, num_processes) ]
    map(lambda p: p.start(), processes)
    map(lambda p: p.join(), processes)
