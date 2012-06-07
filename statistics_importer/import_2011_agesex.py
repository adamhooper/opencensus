#!/usr/bin/env python2.7

import re
from zipfile import ZipFile as _ZipFile

import db
from region_id_finder import RegionIdFinder as _RegionIdFinder

class RegionStatistics:
    def __init__(self):
        self.data = {
            'male': [0] * 21,
            'female': [0] * 21
        }
        self.parsed = False

class RecordDb:
    CodeToSex = {
        '2': 'male',
        '3': 'female'
    }

    CodeToAgeIndex = {
        '3': 0,
        '9': 1,
        '15': 2,
        '22': 3,
        '28': 4,
        '35': 5,
        '41': 6,
        '48': 7,
        '54': 8,
        '61': 9,
        '67': 10,
        '74': 11,
        '80': 12,
        '87': 13,
        '93': 14,
        '99': 15,
        '106': 16,
        '112': 17,
        '118': 18,
        '124': 19,
        '130': 20
    }

    UidLengthToType = {
        'DA': {
            11: 'DisseminationArea',
            7: 'Subdivision',
            4: 'Division',
            2: 'Province'
        },
        'CT': {
            10: 'Tract',
            9: 'Tract',
            3: 'MetropolitanArea'
        },
        'ED': {
            5: 'ElectoralDistrict',
            2: 'Province'
        }
    }

    def __init__(self):
        self._region_id_finder = _RegionIdFinder()
        self._prepopulate()

    def _prepopulate(self):
        self._region_statistics = {}
        for region_id in self._region_id_finder.region_ids(region_types=('Country', 'Province', 'MetropolitanArea', 'Tract', 'ElectoralDistrict', 'DisseminationArea', 'Subdivision', 'Division')):
            self._region_statistics[region_id] = RegionStatistics()

    def _load_data(self, data_file, file_type):
        obs_value_regex = re.compile('generic:ObsValue.*value="(\d+)')
        generic_value_regex = re.compile('generic:Value concept="(\w+)" value="(\d+)')
        age_code = None
        sex_code = None
        region_code = None
        indicator_code = None
        uid_length_to_type = RecordDb.UidLengthToType[file_type]

        for line in data_file:
            m = generic_value_regex.search(line)
            if m:
                concept = m.group(1)
                value = m.group(2)

                if concept == 'GEO':
                    region_code = value
                elif concept == 'AGE':
                    age_code = value
                elif concept == 'Sex':
                    sex_code = value
            else:
                m = obs_value_regex.search(line)
                if m:
                    if age_code in RecordDb.CodeToAgeIndex and sex_code in RecordDb.CodeToSex:
                        region_type = uid_length_to_type[len(region_code)]

                        if region_type == 'DisseminationArea':
                            region_uid = region_code[0:4] + region_code[7:]
                        elif region_type == 'Tract':
                            region_uid = region_code[0:-2] + '.' + region_code[-2:]
                        elif region_type == 'Province' and region_code == '00':
                            region_type = 'Country'
                            region_uid = ''
                        else:
                            region_uid = region_code

                        region_id = self._region_id_finder.get_id_for_type_and_uid(region_type, region_uid)

                        if not region_id: continue

                        value = int(m.group(1))

                        region_statistics = self._region_statistics[region_id]
                        key = RecordDb.CodeToSex[sex_code]
                        index = RecordDb.CodeToAgeIndex[age_code]

                        region_statistics.data[key][index] = value
                        region_statistics.parsed = True

    def import_dissemination_area_zipfile(self, da_zip_filename):
        self.import_zipfile(da_zip_filename, 'DA')

    def import_electoral_district_zipfile(self, ed_zip_filename):
        self.import_zipfile(ed_zip_filename, 'ED')

    def import_tract_zipfile(self, ct_zip_filename):
        self.import_zipfile(ct_zip_filename, 'CT')

    def import_zipfile(self, zip_filename, file_type):
        with _ZipFile(zip_filename, 'r') as zipfile:
            inner_filename = zip_filename.split('/')[-1].split('.')[0]
            data_filename = 'Generic_%s.xml' % (inner_filename,)

            with zipfile.open(data_filename) as data_file:
                self._load_data(data_file, file_type)

    def export_to_database(self):
        connection = db.connect()
        c = connection.cursor()

        c.execute("SELECT id FROM indicators WHERE key = 'agem'")
        agem_id = c.fetchone()[0]
        c.execute("SELECT id FROM indicators WHERE key = 'agef'")
        agef_id = c.fetchone()[0]

        c.execute('DELETE FROM indicator_region_values WHERE indicator_id IN %s', ((agem_id, agef_id),))

        c.execute("""
            PREPARE insert_region_values (INT, CHAR, CHAR) AS
            INSERT INTO indicator_region_values (region_id, indicator_id, value_string)
            VALUES
            ($1, %d, $2),
            ($1, %d, $3)
            """ % (agem_id, agef_id))

        for region_id, statistics in self._region_statistics.items():
            if not statistics.parsed: continue
            for key in ('male', 'female'):
                statistics.data[key][17] = \
                        0 + \
                        statistics.data[key][17] + \
                        statistics.data[key][18] + \
                        statistics.data[key][19] + \
                        statistics.data[key][20]
                statistics.data[key].pop(20)
                statistics.data[key].pop(19)
                statistics.data[key].pop(18)

            c.execute('EXECUTE insert_region_values (%s, %s, %s)',
                    (region_id,
                        ','.join(map(str, statistics.data['male'])),
                        ','.join(map(str, statistics.data['female']))))

        connection.commit()

if __name__ == '__main__':
    import sys

    da_zip_filename = sys.argv[1]
    ct_zip_filename = sys.argv[2]
    ed_zip_filename = sys.argv[3]

    print 'Warming up...'
    record_db = RecordDb()
    print 'Reading ElectoralDistrict zipfile...'
    record_db.import_electoral_district_zipfile(ed_zip_filename)
    print 'Reading Tract zipfile...'
    record_db.import_tract_zipfile(ct_zip_filename)
    print 'Reading DisseminationArea zipfile...'
    record_db.import_dissemination_area_zipfile(da_zip_filename)
    print 'Writing to indicator_region_values...'
    record_db.export_to_database()
