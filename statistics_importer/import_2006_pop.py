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
    def __init__(self, population, note):
        self.population = population
        self.note = note

class RegionCorrespondence:
    def __init__(self, distribution_block_zip_filename, distribution_area_zip_filename):
        self.distribution_blocks = self._zip_to_dict(distribution_block_zip_filename, 2)
        self.distribution_areas = self._zip_to_dict(distribution_area_zip_filename, 3)

    def _zip_filename_to_inner_txt_filename(self, zip_filename):
        return zip_filename.split('/')[-1].replace('_txt.zip', '.txt')

    def _zip_to_dict(self, zip_filename, rel_column):
        ret = {}

        with _ZipFile(zip_filename, 'r') as zipfile:
            inner_filename = self._zip_filename_to_inner_txt_filename(zip_filename)
            with zipfile.open(inner_filename) as inner_file:
                for line in inner_file:
                    columns = line.split(',')
                    old_uid = columns[0]
                    new_uid = columns[1]
                    relation = columns[rel_column]
                    if relation == '1' or relation == '2':
                        ret[old_uid] = new_uid
                    else:
                        ret[old_uid] = None

        return ret

class RecordDb:
    RegionTypeToUidRangeInTextLine = {
        'DisseminationBlock': (0, 10),
        'DisseminationArea': (48, 56),
        'Province': (114, 116),
        'ElectoralDistrict': (237, 242),
        'EconomicRegion': (325, 329),
        'Division': (416, 420),
        'Subdivision': (454, 461),
        'ConsolidatedSubdivision': (519, 526),
        'MetropolitanArea': (666, 671),
        'Tract': (755, 765),
        'Country': (1, 0)
    }

    def __init__(self, correspondences):
        self._region_id_finder = _RegionIdFinder()
        self._prepopulate()
        self._correspondences = correspondences

    def _prepopulate(self):
        self._region_statistics = {}
        for region_id in self._region_id_finder.region_ids():
            self._region_statistics[region_id] = RegionStatistics(0, '')

    def import_zipfile(self, zip_filename):
        with _ZipFile(zip_filename, 'r') as zipfile:
            inner_filename = zip_filename.split('/')[-1][5:].replace('_XBB_txt.zip', '-XBB_TXT.txt')
            with zipfile.open(inner_filename) as inner_file:
                for line in inner_file:
                    line = line.decode('iso-8859-1')
                    for region_type, uid_range in RecordDb.RegionTypeToUidRangeInTextLine.items():
                        uid = line[uid_range[0]:uid_range[1]]

                        if type == 'DisseminationBlock':
                            if uid in self.correspondences.distribution_blocks:
                                uid = self.correspondences.distribution_blocks[uid]
                        elif type == 'DisseminationArea':
                            if uid in self.correspondences.distribution_area:
                                uid = self.correspondences.distribution_areas[uid]

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

    def export_to_database(self):
        connection = db.connect()
        c = connection.cursor()

        c.execute("SELECT id FROM indicators WHERE key = 'pop2006'")
        population_id = c.fetchone()[0]

        c.execute('DELETE FROM indicator_region_values WHERE indicator_id = %s', (population_id,))

        c.execute("""
            PREPARE insert_region_values (INT, INT, CHAR) AS
            INSERT INTO indicator_region_values (region_id, indicator_id, value_integer, note)
            VALUES
            ($1, %d, $2, $3)
            """ % (population_id))

        for region_id, statistics in self._region_statistics.items():
            c.execute('EXECUTE insert_region_values (%s, %s, %s)',
                    (region_id, statistics.population, statistics.note))

        connection.commit()

if __name__ == '__main__':
    import sys

    zip_filename = sys.argv[1]
    db_correspondence_zip_filename = sys.argv[2]
    da_correspondence_zip_filename = sys.argv[3]

    print 'Loading correspondences...'
    correspondences = RegionCorrespondence(db_correspondence_zip_filename, da_correspondence_zip_filename)
    print 'Warming up...'
    record_db = RecordDb(correspondences)
    print 'Reading zipfile...'
    record_db.import_zipfile(zip_filename)
    print 'Writing to indicator_region_values...'
    record_db.export_to_database()
