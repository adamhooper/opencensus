#!/usr/bin/env python2.7
#
# Parses the population and dwelling counts from "Comprehensive download files"
# as downloaded from
# http://www12.statcan.gc.ca/census-recensement/2011/dp-pd/prof/details/page_Download-Telecharger.cfm?Lang=E&Tab=2&Geo1=CD&Code1=4813&Geo2=PR&Code2=01&Data=Count&SearchText=Canada&SearchType=Begins&SearchPR=01&B1=All&Custom=&TABID=1
#
# We need to run this after importing 2006 (and 2011) populations because some
# boundaries have changed since 2006, so the 2006 geographic attribute file is
# only useful for dissemination area/block counts

import csv
import os.path
import sys

import db
from region_id_finder import RegionIdFinder as _RegionIdFinder

class RegionStatistics:
    def __init__(self, population, note):
        self.population = population
        self.note = note

class Loader:
    RegionTypeFilenames = {
        'Province': '98-316-XWE2011001-101.csv',
        'MetropolitanArea': '98-316-XWE2011001-201.csv',
        'Subdivision': '98-316-XWE2011001-301.csv',
        'Tract': '98-316-XWE2011001-401.csv',
        'ElectoralDistrict': '98-316-XWE2011001-501.csv',
        'Division': '98-316-XWE2011001-701.csv',
        'EconomicRegion': '98-316-XWE2011001-901.csv'
    }

    def __init__(self, dirname):
        self._region_id_finder = _RegionIdFinder()
        self.dirname = dirname

    def _region_types_and_filenames(self):
        for region_type, basename in Loader.RegionTypeFilenames.items():
            yield (region_type, os.path.join(self.dirname, basename))

    def _filename_indicator_region_values(self, filename, region_type):
        colstart = {
            '101.csv': 3,
            '201.csv': 5,
            '301.csv': 6,
            '401.csv': 5,
            '501.csv': 4,
            '701.csv': 5,
            '901.csv': 4
        }[filename[-7:]]

        f = open(filename, 'rb')
        reader = csv.reader(f)
        for row in reader:
            if len(row) < 8: continue

            key = None
            if row[colstart] == 'Population in 2011':
                key = 'pop'
            if row[colstart] == 'Population in 2006':
                key = 'pop2006'
            if row[colstart] == 'Total private dwellings':
                key = 'dwe'
            if not key: continue

            if region_type == 'MetropolitanArea' and '(' in row[2]:
                # StatsCan gives three counts for CMAs that cross a provincial
                # boundary. Two have, eg, "(Quebec part)" and "(Ontario part)"
                # in their names.
                continue

            region_code = row[0]

            if region_type == 'Province' and region_code == '1':
                region_id = self._region_id_finder.get_id_for_type_and_uid('Country', '')
            else:
                if region_type == 'Tract':
                    if '.' not in region_code: region_code += '.00'
                    elif region_code[-2] == '.': region_code += '0'
                    region_code = region_code.zfill(10)
                elif region_type == 'MetropolitanArea':
                    region_code = region_code.zfill(3)
                region_id = self._region_id_finder.get_id_for_type_and_uid(region_type, region_code)

            if not region_id:
                print >> sys.stderr, 'Could not find region %s - %s' % (region_type, region_code)
                continue

            value = int(row[colstart+2])

            notes_key = row[colstart+1]
            notes2_key = row[colstart+3]
            notes = []
            if notes_key == '1':
                if region_type == 'Tract':
                    notes.append('Count adjusted slightly to preserve privacy')
            if notes2_key == 'A':
                notes.append('Count adjusted because boundaries changed since the previous census')
            elif notes2_key == '..':
                notes.append('Incompletely enumerated Indian Reserve or Indian Settlement')
            notes = '; '.join(notes)

            yield key, region_id, value, notes

    def _load_file_into_database(self, filename, region_type, c):
        c.execute("SELECT id FROM indicators WHERE key = 'pop'")
        pop_id = c.fetchone()[0]
        c.execute("SELECT id FROM indicators WHERE key = 'dwe'")
        dwe_id = c.fetchone()[0]
        c.execute("SELECT id FROM indicators WHERE key = 'pop2006'")
        pop2006_id = c.fetchone()[0]

        indicator_to_id = {
            'pop': pop_id,
            'dwe': dwe_id,
            'pop2006': pop2006_id
        }

        for key, region_id, value, notes in self._filename_indicator_region_values(filename, region_type):
            indicator_id = indicator_to_id[key]
            c.execute('INSERT INTO indicator_region_values (indicator_id, region_id, value_integer, note) VALUES (%s, %s, %s, %s)',
                    (indicator_id, region_id, value, notes))

    def load_files_into_database(self):
        connection = db.connect()
        c = connection.cursor()

        c.execute('DELETE FROM indicator_region_values WHERE region_id IN (SELECT id FROM regions WHERE type IN %s) AND indicator_id IN (SELECT id FROM indicators WHERE key IN %s)',
                (
                    ('Country', 'Province', 'MetropolitanArea', 'Subdivision', 'ConsolidatedSubdivision', 'Tract', 'ElectoralDistrict', 'Division', 'EconomicRegion'),
                    ('pop', 'dwe', 'pop2006')
                ))

        for region_type, filename in self._region_types_and_filenames():
            print >> sys.stderr, 'Loading %s (%s)' % (region_type, filename)
            self._load_file_into_database(filename, region_type, c)

        c.execute("""
            INSERT INTO indicator_region_values (indicator_id, region_id, value_integer, note)
            SELECT irv.indicator_id, rp.parent_region_id, SUM(irv.value_integer), ''
            FROM indicator_region_values irv
            INNER JOIN region_parents rp ON irv.region_id = rp.region_id
            WHERE irv.indicator_id IN (SELECT id FROM indicators WHERE key IN ('pop', 'dwe', 'pop2006'))
              AND rp.parent_region_id IN (SELECT id FROM regions WHERE type = 'ConsolidatedSubdivision')
            GROUP BY irv.indicator_id, rp.parent_region_id
            """)

        connection.commit()

if __name__ == '__main__':
    dirname = sys.argv[1]

    print 'Warming up...'
    loader = Loader(dirname)
    print 'Reading CSVs and writing to database...'
    loader.load_files_into_database()
