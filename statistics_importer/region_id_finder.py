import db

class RegionIdFinder(object):
    def __init__(self):
        self._populate()

    def get_id_for_type_and_uid(self, region_type, uid):
        try:
            return self._data[region_type][uid]
        except KeyError:
            return None

    def region_ids(self):
        for subdict in self._data.values():
            for region_id in subdict.values():
                yield region_id

    def _populate(self):
        self._data = {}

        connection = db.connect()
        c = connection.cursor()

        c.execute('SELECT name FROM region_types')
        for row in c:
            name = row[0]
            self._data[name] = {}

        c.execute('SELECT id, type, uid FROM regions')
        for row in c:
            self._data[row[1]][row[2]] = row[0]
