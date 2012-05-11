#!/usr/bin/env python2.7

import json

from work_queue import WorkQueue as _WorkQueue
from utf_grid_builder import UTFGridBuilder as _UTFGridBuilder
from region_types import as_sets as _get_region_type_sets
from tile import Tile as _Tile
from coord import Coord as _Coord

def _dump_json(obj):
    return json.dumps(obj, ensure_ascii=False, check_circular=False, separators=(',', ':'))

def create_worker(db, tile_size):
    cursor = db.cursor()
    cursor.execute('''
        PREPARE select_data (INT, INT, INT) AS
        SELECT r.type, r.uid, ST_AsSVG(ST_Collect(rpt.geometry_srid3857)) AS svg
        FROM region_polygon_tiles rpt
        INNER JOIN region_polygons_metadata rpm ON rpt.region_polygon_id = rpm.region_polygon_id
        INNER JOIN regions r ON rpm.region_id = r.id
        WHERE rpt.zoom_level = $1 AND rpt.tile_row = $2 AND rpt.tile_column = $3
        GROUP BY r.type, r.uid, r.position
        ORDER BY r.position
        ''')
    cursor.execute('''
        PREPARE insert_processed_data (INT, INT, INT, TEXT) AS
        INSERT INTO utfgrids (zoom_level, tile_row, tile_column, utfgrids)
        VALUES ($1, $2, $3, $4)
        ''')

    region_type_sets = _get_region_type_sets()

    def worker(zoom_level, tile_row, tile_column):
        coord = _Coord(tile_row, tile_column, zoom_level)
        tile = _Tile(tile_size, tile_size, coord)

        builders = [ ( rts, _UTFGridBuilder(tile) ) for rts in region_type_sets ]

        cursor.execute('EXECUTE select_data (%s, %s, %s)', (zoom_level, tile_row, tile_column))
        for region_type, region_uid, svg in cursor:
            json_id = region_type + '-' + region_uid
            for rts, builder in builders:
                if region_type in rts:
                    builder.add(svg, json_id)

        utfgrid_objects = []

        for rts, builder in builders:
            utfgrid = builder.get_utfgrid()
            utfgrid.simplify()
            if len(utfgrid.keys) > 1 or utfgrid.keys[0] != '': # if there's a region
                obj = { 'grid': utfgrid.grid, 'keys': utfgrid.keys }
                if obj not in utfgrid_objects:
                    utfgrid_objects.append(obj)

        json_str = _dump_json(utfgrid_objects)

        cursor.execute('EXECUTE insert_processed_data (%s, %s, %s, %s)', (zoom_level, tile_row, tile_column , json_str))

    return worker

def main():
    import db
    source_db = db.connect()

    worker = create_worker(source_db, 256)
    work_queue = _WorkQueue(source_db, 'work_queue2', [ 'zoom_level', 'tile_row', 'tile_column' ], worker)
    work_queue.work()

if __name__ == '__main__':
    from multiprocessing import Process, cpu_count
    num_processes = cpu_count()

    processes = [ Process(target=main) for x in xrange(0, num_processes) ]
    map(lambda p: p.start(), processes)
    map(lambda p: p.join(), processes)
