#!/usr/bin/env python

import json

from utf_grid_builder import UTFGridBuilder

def _json_encode(s):
    return json.dumps(s, ensure_ascii = False)

class TileData(object):
    def __init__(self, tile):
        self.tile = tile
        self.utfgrid_builder = UTFGridBuilder(tile)
        self.geojson_features = []
        self.region_id_to_properties = {}

    def __len__(self):
        return len(self.geojson_features)

    def addRegion(self, region_id, properties, geometry_geojson, geometry_mercator_svg):
        json_id = properties['type'] + '-' + properties['uid']
        feature = { 'json_id': json_id, 'properties': properties, 'geometry_geojson': geometry_geojson }

        self.geojson_features.append(feature)
        self.region_id_to_properties[region_id] = feature['properties']
        self.utfgrid_builder.add(geometry_mercator_svg, json_id)

    def addRegionStatistic(self, region_id, year, name, value, note):
        properties = self.region_id_to_properties[region_id]
        if 'statistics' not in properties: properties['statistics'] = {}
        statistics = properties['statistics']
        if str(year) not in statistics: statistics[str(year)] = {}
        year_statistics = statistics[str(year)]
        year_statistics[name] = { 'value': value }
        if note is not None and len(note) > 0:
            year_statistics[name]['note'] = note

    def toJson(self):
        feature_jsons = []
        for feature in self.geojson_features:
            json_id = _json_encode(feature['json_id'])
            json_properties = _json_encode(feature['properties'])
            json_geometry = feature['geometry_geojson']
            s = u'{"type":"Feature","id":%s,"properties":%s,"geometry":%s}' % (json_id, json_properties, json_geometry)
            feature_jsons.append(s)

        utfgrid = self.utfgrid_builder.get_utfgrid_data()

        content = u'{"type":"FeatureCollection","features":[%s],"utfgrid":%s}' % (','.join(feature_jsons), _json_encode(utfgrid))

        return content
