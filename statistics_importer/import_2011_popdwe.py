#!/usr/bin/env python2.7
#
# Parses the "Geographic Attribute File" from StatsCan 2011.
# http://geodepot.statcan.gc.ca/2006/040120011618150421032019/02152114040118250609120519/021521140401182519011205_05-eng.jsp?catno=92-151-XBB
#
# (File format is described in a PDF in that zipfile.)

from zipfile import ZipFile as _ZipFile

import db
from region_id_finder import RegionIdFinder as _RegionIdFinder

class RegionStatistics:
    def __init__(self, population, n_dwellings, n_occupied_dwellings, note):
        self.population = population
        self.n_dwellings = n_dwellings
        self.n_occupied_dwellings = n_occupied_dwellings
        self.note = note

class RecordDb:
    RegionTypeToUidRangeInTextLine = {
        'DisseminationBlock': (0, 10), # 1, 10
        'DisseminationArea': (48, 56), # 49, 8
        'Province': (110, 112), # 111, 2
        'ElectoralDistrict': (247, 252), # 248, 5
        'EconomicRegion': (337, 341), # 338, 4
        'Division': (426, 430), # 427, 4
        'Subdivision': (473, 480), # 474, 7
        'ConsolidatedSubdivision': (542, 549), # 543, 7
        'MetropolitanArea': (703, 706), # 704, 3
        'Tract': (807, 817), # 808, 10.2
        'Country': (1, 0) # empty-string UID
    }

    def __init__(self):
        self._region_id_finder = _RegionIdFinder()
        self._prepopulate()

    def _prepopulate(self):
        self._region_statistics = {}
        for region_id in self._region_id_finder.region_ids():
            self._region_statistics[region_id] = RegionStatistics(0, 0, 0, '')

    def import_zipfile(self, zip_filename):
        with _ZipFile(zip_filename, 'r') as zipfile:
            inner_filename = zip_filename.split('/')[-1].replace('_txt.zip', '_TXT.txt')
            with zipfile.open(inner_filename) as inner_file:
                for line in inner_file:
                    line = line.decode('iso-8859-1')
                    for region_type, uid_range in RecordDb.RegionTypeToUidRangeInTextLine.items():
                        uid = line[uid_range[0]:uid_range[1]]
                        region_id = self._region_id_finder.get_id_for_type_and_uid(region_type, uid)

                        if region_id:
                            region_statistics = self._region_statistics[region_id]

                            if line[47] == 'T':
                                if region_type in ('Subdivision', 'Tract', 'DisseminationArea', 'DisseminationBlock'):
                                    region_statistics.note = 'counts for Indian reserves and settlements are not complete'
                            else:
                                population = int(line[10:18])
                                n_dwellings = int(line[18:26])
                                n_occupied_dwellings = int(line[26:34])

                                region_statistics.population += population
                                region_statistics.n_dwellings += n_dwellings
                                region_statistics.n_occupied_dwellings += n_occupied_dwellings

    def export_to_database(self):
        connection = db.connect()
        c = connection.cursor()

        c.execute("SELECT id FROM indicators WHERE name = 'Population'")
        population_id = c.fetchone()[0]
        c.execute("SELECT id FROM indicators WHERE name = 'Dwellings'")
        dwellings_id = c.fetchone()[0]
        c.execute("SELECT id FROM indicators WHERE name = 'Occupied dwellings'")
        occupied_dwellings_id = c.fetchone()[0]

        c.execute('DELETE FROM indicator_region_values WHERE indicator_id IN %s', ((population_id, dwellings_id, occupied_dwellings_id),))

        c.execute("""
            PREPARE insert_region_values (INT, INT, INT, INT, CHAR) AS
            INSERT INTO indicator_region_values (region_id, indicator_id, value_integer, note)
            VALUES
            ($1, %d, $2, $5),
            ($1, %d, $3, $5),
            ($1, %d, $4, $5)
            """ % (population_id, dwellings_id, occupied_dwellings_id))

        for region_id, statistics in self._region_statistics.items():
            c.execute('EXECUTE insert_region_values (%s, %s, %s, %s, %s)',
                    (region_id, statistics.population, statistics.n_dwellings,
                        statistics.n_occupied_dwellings, statistics.note))

        connection.commit()

if __name__ == '__main__':
    import sys

    zip_filename = sys.argv[1]

    print 'Warming up...'
    record_db = RecordDb()
    print 'Reading zipfile...'
    record_db.import_zipfile(zip_filename)
    print 'Writing to indicator_region_values...'
    record_db.export_to_database()
