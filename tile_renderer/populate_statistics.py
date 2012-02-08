#!/usr/bin/env python

__requires__ = ['psycopg2==2.4.4']
import pkg_resources

import sqlite3
import zlib

import psycopg2
import psycopg2.extensions
psycopg2.extensions.register_type(psycopg2.extensions.UNICODE)
psycopg2.extensions.register_type(psycopg2.extensions.UNICODEARRAY)

import opencensus_json

class Indicator(object):
    def __init__(self, name, value_type):
        self.name = name
        self.value_type = value_type

    def row_to_data(self, value_integer, value_float, note):
        value = None
        if self.value_type == 'integer': value = int(value_integer)
        elif self.value_type == 'float': value = float(value_float)

        ret = { 'value': value }
        if note is not None and len(note) > 0:
            ret['note'] = note

        return ret

class Region(object):
    def __init__(self):
        self.data = {}

    def add_year_indicator_data(self, year, indicator, value):
        year = str(year)
        if year not in self.data: self.data[year] = {}
        year_data = self.data[year]
        year_data[indicator.name] = data

if __name__ == '__main__':
    import sys

    read_dsn = 'dbname=opencensus_dev user=opencensus_dev password=opencensus_dev host=localhost'
    write_dsn = sys.argv[1]

    read_db = psycopg2.connect(read_dsn)
    write_db = sqlite3.connect(write_dsn)

    read_cursor = read_db.cursor()
    write_cursor = write_db.cursor()

    write_cursor.execute('PRAGMA synchronous = OFF')

    print 'Creating output database...'
    write_cursor.execute('CREATE TABLE region_statistics (region_id INTEGER PRIMARY KEY, statistics BLOB)')

    print 'Loading indicators...'
    sys.stdout.flush()
    read_cursor.execute('SELECT id, name, value_type FROM indicators')
    indicators = {}
    for (id, name, value_type) in read_cursor:
        indicators[id] = Indicator(name, value_type)

    print 'Loading list of region IDs...'
    read_cursor.execute('SELECT DISTINCT region_id FROM indicator_region_values')
    all_region_ids = [ row[0] for row in read_cursor ]

    print 'Loading statistics per region and writing to SQLite ("qrw" = 1,000 regions queried, read and written)'
    spread = 1000

    for i in xrange(0, len(all_region_ids), spread):
        region_ids = all_region_ids[i:i+spread]

        read_cursor.execute('SELECT region_id, indicator_id, year, value_integer, value_float, note FROM indicator_region_values WHERE region_id IN (%s)' % (','.join(map(str, region_ids)),))
        sys.stdout.write('q'); sys.stdout.flush()

        regions = {}
        for (region_id, indicator_id, year, value_integer, value_float, note) in read_cursor:
            if region_id not in regions: regions[region_id] = Region()
            region = regions[region_id]
            indicator = indicators[indicator_id]
            data = indicator.row_to_data(value_integer, value_float, note)
            region.add_year_indicator_data(int(year), indicator, data)

        sys.stdout.write('r'); sys.stdout.flush()

        for region_id in regions:
            region = regions[region_id]
            json_statistics = opencensus_json.encode(region.data)
            json_statistics_z = zlib.compress(json_statistics.encode('utf-8'))
            write_cursor.execute('INSERT INTO region_statistics (region_id, statistics) VALUES (?, ?)', (region_id, buffer(json_statistics_z)))
            write_db.commit()

        sys.stdout.write('w'); sys.stdout.flush()
    print

    write_db.commit()
    print 'Done!'
