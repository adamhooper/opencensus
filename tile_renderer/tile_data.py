#!/usr/bin/env python

from db import source_db as _source_db
import json

from utf_grid_builder import UTFGridBuilder

class _Node(object):
    def __init__(self, region_type, children):
        self.region_type = region_type
        self.children = children

class _NodeSet(object):
    def __init__(self):
        self.nodes = {}

    def getNode(self, region_type):
        if region_type not in self.nodes:
            self.nodes[region_type] = _Node(region_type, [])
        return self.nodes[region_type]

    def getRootNode(self):
        candidates = set(self.nodes.keys())
        not_root = set()

        for node in self.nodes.itervalues():
            for child_node in node.children:
                region_type = child_node.region_type
                not_root.add(region_type)

        candidates -= not_root

        return candidates.pop()

    # Returns [[ 'Province', 'EconomicRegion', 'DisseminationBlock'], [ 'Province', 'MetropolitanArea', ...], ...]
    def getHierarchyPaths(self):
        # A breadth-first search
        paths = [[self.getRootNode()]]
        finished = False

        while not finished:
            finished = True # maybe
            next_paths = []
            for path in paths:
                end_node = self.nodes[path[-1]]
                if len(end_node.children) > 0:
                    finished = False
                    for further_node in end_node.children:
                        next_paths.append(path + [further_node.region_type])
                else:
                    next_paths.append(path)
            paths = next_paths

        return paths

_region_type_sets = None
def _getRegionTypeSets():
    global _region_type_sets
    if _region_type_sets is not None:
        return _region_type_sets

    nodes = _NodeSet()
    root_region_type_candidates = set()

    sql = 'SELECT parent_region_type, region_type FROM region_type_parents'
    cursor = _source_db.cursor()
    cursor.execute(sql)

    for row in cursor:
        parent_region_type, region_type = row
        parent_node = nodes.getNode(parent_region_type)
        child_node = nodes.getNode(region_type)
        parent_node.children.append(child_node)

    paths = nodes.getHierarchyPaths()
    print "Paths: %r" % (paths,)

    _region_type_sets = map(set, paths)
    return _region_type_sets

def _json_encode(s):
    return json.dumps(s, ensure_ascii = False)

class TileData(object):
    def __init__(self, tile):
        self.tile = tile
        self.utfgrid_builders = []
        for _unused in _getRegionTypeSets():
            self.utfgrid_builders.append(UTFGridBuilder(tile))
        self.geojson_features = []
        self.region_id_to_properties = {}

    def __len__(self):
        return len(self.geojson_features)

    def addRegion(self, region_id, properties, geometry_geojson, geometry_mercator_svg):
        json_id = properties['type'] + '-' + properties['uid']
        feature = { 'json_id': json_id, 'properties': properties, 'geometry_geojson': geometry_geojson }

        self.geojson_features.append(feature)
        self.region_id_to_properties[region_id] = feature['properties']

        for i, region_type_set in enumerate(_getRegionTypeSets()):
            if properties['type'] in region_type_set:
                self.utfgrid_builders[i].add(geometry_mercator_svg, json_id)

    def addRegionStatistic(self, region_id, year, name, value, note):
        properties = self.region_id_to_properties[region_id]
        if 'statistics' not in properties: properties['statistics'] = {}
        statistics = properties['statistics']
        if str(year) not in statistics: statistics[str(year)] = {}
        year_statistics = statistics[str(year)]
        year_statistics[name] = { 'value': value }
        if note is not None and len(note) > 0:
            year_statistics[name]['note'] = note

    def regionIds(self):
        return self.region_id_to_properties.keys()

    def toJson(self):
        feature_jsons = []
        for feature in self.geojson_features:
            json_id = _json_encode(feature['json_id'])
            json_properties = _json_encode(feature['properties'])
            json_geometry = feature['geometry_geojson']
            s = u'{"type":"Feature","id":%s,"properties":%s,"geometry":%s}' % (json_id, json_properties, json_geometry)
            feature_jsons.append(s)

        utfgrids = [ builder.get_utfgrid_data() for builder in self.utfgrid_builders ]

        content = u'{"type":"FeatureCollection","features":[%s],"utfgrids":%s}' % (','.join(feature_jsons), _json_encode(utfgrids))

        return content
