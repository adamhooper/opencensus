#!/usr/bin/env python

import json

from utf_grid_builder import UTFGridBuilder
import region_types

def _decode_geojson(obj):
    return json.loads(obj)

_region_type_sets = region_types.as_sets()

class TileData(object):
    def __init__(self, features=[], utfgrids=None, render_utfgrid_for_tile=None):
        if render_utfgrid_for_tile is not None:
            self._utfgrids = None
            self.utfgrid_builders = []
            for _unused in _region_type_sets:
                self.utfgrid_builders.append(UTFGridBuilder(render_utfgrid_for_tile))
        elif utfgrids:
            self._utfgrids = utfgrids
        else:
            raise ValueError('TileData() must receive either "utfgrids" or "render_utfgrid_for_tile" kwarg')

        self.features = []
        self.region_id_to_properties = {}
        for feature in features:
            self.region_id_to_properties[feature['id']] = feature['properties']

    def __len__(self):
        return len(self.features)

    def addRegion(self, region_id, properties, geometry_geojson, geometry_mercator_svg=None):
        geometry = _decode_geojson(geometry_geojson)
        feature = { 'type': 'Feature', 'id': region_id, 'properties': properties, 'geometry': geometry }
        self.features.append(feature)

        self.region_id_to_properties[region_id] = feature['properties']

        if geometry_mercator_svg is not None and self._utfgrids is None:
            for i, region_type_set in enumerate(_region_type_sets):
                if properties['type'] in region_type_set:
                    self.utfgrid_builders[i].add(geometry_mercator_svg, region_id)

    def addRegionStatistic(self, region_id, year, name, value, note):
        properties = self.region_id_to_properties[region_id]
        if 'statistics' not in properties: properties['statistics'] = {}
        statistics = properties['statistics']
        if str(year) not in statistics: statistics[str(year)] = {}
        year_statistics = statistics[str(year)]
        year_statistics[name] = { 'value': value }
        if note is not None and len(note) > 0:
            year_statistics[name]['note'] = note

    def utfgrids(self):
        if self._utfgrids is not None: return self._utfgrids

        self._utfgrids = []

        for builder in self.utfgrid_builders:
            grid = builder.get_utfgrid()
            grid.simplify()
            if len(grid.keys) > 1 or grid.keys[0] != '': # if there's a region
                if grid not in self._utfgrids:
                    self._utfgrids.append(grid)

        return self._utfgrids

    def containsRegionBoundaries(self):
        grids = self.utfgrids()

        for grid in grids:
            if len(grid.keys) > 1: return True

        return False
