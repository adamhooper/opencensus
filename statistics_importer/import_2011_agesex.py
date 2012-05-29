#!/usr/bin/env python2.7

# This is a TEST. We'll replace it with "import_2011_agesex.py".

from zipfile import ZipFile as _ZipFile
from xml.etree import cElementTree as _ElementTree

import db
from region_id_finder import RegionIdFinder as _RegionIdFinder

class RegionStatistics:
    def __init__(self):
        self.data = {
            'male': [0] * 18,
            'female': [0] * 18
        }
        self.parsed = False

class RecordDb:
    CodeToSexAndAge = {
        '7': ('male', 0),
        '8': ('male', 1),
        '9': ('male', 2),
        '10': ('male', 3),
        '11': ('male', 4),
        '12': ('male', 5),
        '13': ('male', 6),
        '14': ('male', 7),
        '15': ('male', 8),
        '16': ('male', 9),
        '17': ('male', 10),
        '18': ('male', 11),
        '19': ('male', 12),
        '20': ('male', 13),
        '21': ('male', 14),
        '22': ('male', 15),
        '23': ('male', 16),
        '24': ('male', 17),
        '26': ('female', 0),
        '27': ('female', 1),
        '28': ('female', 2),
        '29': ('female', 3),
        '30': ('female', 4),
        '31': ('female', 5),
        '32': ('female', 6),
        '33': ('female', 7),
        '34': ('female', 8),
        '35': ('female', 9),
        '36': ('female', 10),
        '37': ('female', 11),
        '38': ('female', 12),
        '39': ('female', 13),
        '40': ('female', 14),
        '41': ('female', 15),
        '42': ('female', 16),
        '43': ('female', 17)
    }

    def __init__(self):
        self._region_id_finder = _RegionIdFinder()
        self._prepopulate()

    def _prepopulate(self):
        self._region_statistics = {}
        for region_id in self._region_id_finder.region_ids(region_types=('MetropolitanArea', 'Tract')):
            self._region_statistics[region_id] = RegionStatistics()

    def _load_data(self, data_file):
        region_code = None
        indicator_code = None

        for event, elem in _ElementTree.iterparse(data_file):
            if elem.tag.endswith('ObsValue'):
                if indicator_code in RecordDb.CodeToSexAndAge:
                    if len(region_code) == 3:
                        region_type = 'MetropolitanArea'
                        region_uid = region_code # so we can cache it
                    else:
                        region_type = 'Tract'
                        region_uid = region_code[0:7] + '.' + region_code[7:]

                    region_id = self._region_id_finder.get_id_for_type_and_uid(region_type, region_uid)

                    if not region_id: continue

                    value = int(elem.get('value'))

                    region_statistics = self._region_statistics[region_id]
                    (key, index) = RecordDb.CodeToSexAndAge[indicator_code]
                    region_statistics.data[key][index] = value
                    region_statistics.parsed = True
            elif elem.tag.endswith('Value'):
                if elem.get('concept') == 'GEO': region_code = elem.get('value')
                elif elem.get('concept') == 'A06_SexAge49_D1': indicator_code = elem.get('value')
        

    def import_zipfile(self, zip_filename):
        with _ZipFile(zip_filename, 'r') as zipfile:
            inner_filename = zip_filename.split('/')[-1].split('.')[0]
            data_filename = 'Generic_%s.xml' % (inner_filename,)

            with zipfile.open(data_filename) as data_file:
                self._load_data(data_file)

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
            c.execute('EXECUTE insert_region_values (%s, %s, %s)',
                    (region_id, ','.join(map(str, statistics.data['male'])),
                    ','.join(map(str, statistics.data['female']))))

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
