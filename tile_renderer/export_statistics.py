#!/usr/bin/env python2.7

import zlib

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

import opencensus_json
import db

class Indicator(object):
    def __init__(self, name, value_type):
        self.name = name
        self.value_type = value_type

    def row_to_data(self, value_integer, value_float, value_string, note):
        value = None
        if self.value_type == 'integer': value = int(value_integer)
        elif self.value_type == 'float': value = float(value_float)
        elif self.value_type == 'string': value = value_string

        ret = { 'value': value }
        if note is not None and len(note) > 0:
            ret['note'] = note

        return ret

if __name__ == '__main__':
    import sys

    read_db = db.connect()

    read_cursor = read_db.cursor()

    print 'PRAGMA synchronous = OFF;'

    print >> sys.stderr, 'Creating output database...'
    print 'CREATE TABLE region_statistics (region_id INTEGER PRIMARY KEY, statistics BLOB);'

    print >> sys.stderr, 'Loading indicators...'

    read_cursor.execute('SELECT id, name, value_type FROM indicators')
    indicators = {}
    for (id, name, value_type) in read_cursor:
        indicators[id] = Indicator(name, value_type)

    print >> sys.stderr, 'Loading list of region IDs...'
    read_cursor.execute('SELECT DISTINCT id FROM regions ORDER BY id')
    all_region_ids = [ row[0] for row in read_cursor ]

    print >> sys.stderr, 'Loading statistics per region and writing to SQLite ("qrw" = 1,000 regions queried, read and written)'
    spread = 1000

    for i in xrange(0, len(all_region_ids), spread):
        region_ids = all_region_ids[i:i+spread]

        read_cursor.execute('SELECT region_id, indicator_id, value_integer, value_float, value_string, note FROM indicator_region_values WHERE region_id IN (%s)' % (','.join(map(str, region_ids)),))
        sys.stderr.write('q'); sys.stderr.flush()

        region_statistics = {}

        for (region_id, indicator_id, value_integer, value_float, value_string, note) in read_cursor:
            if region_id not in region_statistics: region_statistics[region_id] = {}
            statistics = region_statistics[region_id]
            indicator = indicators[indicator_id]
            data = indicator.row_to_data(value_integer, value_float, value_string, note)
            statistics[indicator.name] = data

        sys.stderr.write('r'); sys.stderr.flush()

        for region_id, statistics in region_statistics.items():
            json_statistics = opencensus_json.encode(statistics)
            json_statistics_z = zlib.compress(json_statistics.encode('utf-8'))
            print "INSERT INTO region_statistics (region_id, statistics) VALUES (%d, X'%s');" % (region_id, json_statistics_z.encode('hex'))

        sys.stderr.write('w'); sys.stderr.flush()
    print

    print 'Done!'
