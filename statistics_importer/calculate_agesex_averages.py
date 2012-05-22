#!/usr/bin/env python2.7

import db
from array import array as _array

class RegionStatistics:
    MeanAges = [ 2.5, 7.5, 12.5, 17.5, 22.5, 27.5, 32.5, 37.5, 42.5, 47.5, 52.5, 57.5, 62.5, 67.5, 72.5, 77.5, 82.5, 87.5 ]

    def __init__(self, agem_string, agef_string):
        self.agem = map(int, agem_string.split(','))
        self.agef = map(int, agef_string.split(','))

    def process(self):
        sums = [ self.agem[i] + self.agef[i] for i in xrange(0, len(self.agem)) ]

        count = sum(sums)

        if count == 0:
            self.mean = None
            self.median = None
            self.male_percentage = None
            return

        mean_sums = [ sums[i] * RegionStatistics.MeanAges[i] for i in xrange(0, len(sums)) ]
        self.mean = sum(mean_sums) / count

        median_array = _array('f')
        for i, bucket_count in enumerate(sums):
            if bucket_count <= 0: continue
            # We'll spread points out evenly, like this:
            # given: 0 [-----------------------------] 4 (i.e., <5)
            # and a count of three:
            # 1. Divide into three
            #        0 [---------|---------|---------] 5
            # 2. Put the counts halfway
            #        0 [----x----|----x----|----x----] 5
            # Ages: 5/6, 15/6, 25/6
            gap = 5.0 / bucket_count
            bottom = i * 5.0
            nextval = bottom + gap / 2

            for i in xrange(0, bucket_count):
                median_array.append(nextval)
                nextval += gap

        self.median = median_array[len(median_array)/2]

        count_male = sum(self.agem)
        self.male_percentage = 100.0 * float(count_male) / count

class RecordDb:
    def __init__(self):
        pass

    def load_distributions_from_database(self):
        self._region_statistics = {}

        connection = db.connect()
        c = connection.cursor()

        c.execute("SELECT id FROM indicators WHERE key = 'agem'")
        agem_id = int(c.fetchone()[0])
        c.execute("SELECT id FROM indicators WHERE key = 'agef'")
        agef_id = int(c.fetchone()[0])

        c.execute("""
            SELECT i1.region_id, i1.value_string, i2.value_string
            FROM indicator_region_values i1
            INNER JOIN indicator_region_values i2
              ON i1.region_id = i2.region_id
              AND i2.indicator_id = %s
            WHERE i1.indicator_id = %s
            """, (agef_id, agem_id))
        for region_id, agem_string, agef_string in c:
            stats = RegionStatistics(agem_string, agef_string)
            self._region_statistics[region_id] = stats

    def process(self):
        for stats in self._region_statistics.values():
            stats.process()

    def export_to_database(self):
        connection = db.connect()
        c = connection.cursor()

        c.execute("SELECT id FROM indicators WHERE key = 'agemean'")
        agemean_id = int(c.fetchone()[0])
        c.execute("SELECT id FROM indicators WHERE key = 'agemedian'")
        agemedian_id = int(c.fetchone()[0])
        c.execute("SELECT id FROM indicators WHERE key = 'sexm'")
        sexm_id = int(c.fetchone()[0])

        c.execute("""
            PREPARE insert_statistics (INT, FLOAT, FLOAT, FLOAT) AS
            INSERT INTO indicator_region_values (region_id, indicator_id, value_float)
            VALUES
            ($1, %d, $2),
            ($1, %d, $3),
            ($1, %d, $4)""" % (agemean_id, agemedian_id, sexm_id))

        for region_id, stats in self._region_statistics.items():
            if stats.mean is None: continue
            c.execute('EXECUTE insert_statistics (%s, %s, %s, %s)'
                    % (region_id, stats.mean, stats.median, stats.male_percentage))

        connection.commit()

if __name__ == '__main__':
    print 'Warming up...'
    record_db = RecordDb()
    print 'Reading age/sex profiles...'
    record_db.load_distributions_from_database()
    print 'Calculating...'
    record_db.process()
    print 'Writing averages...'
    record_db.export_to_database()
