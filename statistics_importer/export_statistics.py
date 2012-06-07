#!/usr/bin/env python2.7

import json
import zlib

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

source_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'

class Indicator(object):
    def __init__(self, key, value_type):
        self.key = key
        self.value_type = value_type

    def row_to_data(self, value_integer, value_float, value_string, note, child_zoom_level):
        value = None
        if self.value_type == 'integer': value = int(value_integer)
        elif self.value_type == 'float': value = float(value_float)
        elif self.value_type == 'string': value = value_string

        ret = { 'value': value, 'z': child_zoom_level }
        if note is not None and len(note) > 0:
            ret['note'] = note

        return ret

if __name__ == '__main__':
    import sys

    read_db = psycopg2.connect(source_dsn)

    read_cursor = read_db.cursor()

    print 'PRAGMA synchronous = OFF;'

    print >> sys.stderr, 'Creating output database...'
    print 'CREATE TABLE region_statistics (region_id INTEGER PRIMARY KEY, statistics BLOB);'

    print >> sys.stderr, 'Loading indicators...'

    read_cursor.execute('SELECT id, key, value_type FROM indicators')
    indicators = {}
    for (id, key, value_type) in read_cursor:
        indicators[id] = Indicator(key, value_type)

    print >> sys.stderr, 'Loading list of region IDs...'
    read_cursor.execute('SELECT DISTINCT id FROM regions ORDER BY id')
    all_region_ids = [ row[0] for row in read_cursor ]

    # When a region has children which will display a given indicator at a
    # certain zoom level, the parent should not.
    # Rephrased: the maximum zoom at which an indicator should be displayed
    # is (minimum zoom of any child with that indicator value) - 1.
    # Speed-up: we know that all sibling regions have the same zoom level.
    print >> sys.stderr, 'Loading zoom levels per region/indicator...'
    read_cursor.execute('''
        SELECT rp.parent_region_id, ci.indicator_id, MIN(rmzl.min_zoom_level) AS min_zoom_level
        FROM region_parents rp
        INNER JOIN region_min_zoom_levels rmzl ON rp.region_id = rmzl.region_id
        INNER JOIN indicator_region_values ci ON rp.region_id = ci.region_id
        GROUP BY rp.parent_region_id, ci.indicator_id
        ''')
    region_indicator_zoom_levels = {}
    for region_id, indicator_id, child_min_zoom_level in read_cursor:
        if region_id not in region_indicator_zoom_levels:
            region_indicator_zoom_levels[region_id] = {}
        region_indicator_zoom_levels[region_id][indicator_id] = child_min_zoom_level

    print >> sys.stderr, 'Loading statistics per region and writing to SQLite ("qrw" = 1,000 regions queried, read and written)'
    spread = 1000

    for i in xrange(0, len(all_region_ids), spread):
        region_ids = all_region_ids[i:i+spread]

        q = """
            SELECT
                i.region_id, i.indicator_id, i.value_integer,
                i.value_float, i.value_string, i.note
            FROM indicator_region_values i
            WHERE region_id IN (%s)""" % (','.join(map(str, region_ids)),)
        read_cursor.execute(q)
        sys.stderr.write('q'); sys.stderr.flush()

        region_statistics = {}

        for (region_id, indicator_id, value_integer, value_float, value_string, note) in read_cursor:
            if region_id not in region_statistics: region_statistics[region_id] = {}
            if region_id in region_indicator_zoom_levels \
                    and indicator_id in region_indicator_zoom_levels[region_id]:
                child_zoom_level = region_indicator_zoom_levels[region_id][indicator_id]
            else:
                child_zoom_level = 16

            statistics = region_statistics[region_id]
            indicator = indicators[indicator_id]
            data = indicator.row_to_data(value_integer, value_float, value_string, note, child_zoom_level)
            statistics[indicator.key] = data

        sys.stderr.write('r'); sys.stderr.flush()

        for region_id, statistics in region_statistics.items():
            json_statistics = json.dumps(statistics, ensure_ascii=False, check_circular=False, separators=(',', ':'))
            json_statistics_z = zlib.compress(json_statistics.encode('utf-8'))
            print "INSERT INTO region_statistics (region_id, statistics) VALUES (%d, X'%s');" % (region_id, json_statistics_z.encode('hex'))

        sys.stderr.write('w'); sys.stderr.flush()
    print >> sys.stderr

    print >> sys.stderr, 'Done!'
