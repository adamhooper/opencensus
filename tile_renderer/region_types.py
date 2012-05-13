#!/usr/bin/env python

import db

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

    def getRootRegionTypes(self):
        candidates = set(self.nodes.keys())
        not_root = set()

        for node in self.nodes.itervalues():
            for child_node in node.children:
                region_type = child_node.region_type
                not_root.add(region_type)

        candidates -= not_root

        return list(candidates)

    # Returns [[ 'Province', 'EconomicRegion', 'DisseminationBlock'], [ 'MetropolitanArea', ...], ...]
    def getHierarchyPaths(self):
        # A breadth-first search
        paths = [[region_type] for region_type in self.getRootRegionTypes()]
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

_region_type_lists = None
def as_lists():
    global _region_type_lists
    if _region_type_lists is not None:
        return _region_type_lists

    nodes = _NodeSet()
    root_region_type_candidates = set()

    sql = 'SELECT parent_region_type, region_type FROM region_type_parents'
    cursor = db.connect().cursor()
    cursor.execute(sql)

    for row in cursor:
        parent_region_type, region_type = row
        parent_node = nodes.getNode(parent_region_type)
        child_node = nodes.getNode(region_type)
        parent_node.children.append(child_node)

    _region_type_lists = nodes.getHierarchyPaths()
    return _region_type_lists

_region_type_sets = None
def as_sets():
    global _region_type_sets
    if _region_type_sets is not None:
        return _region_type_sets

    paths = as_lists()

    # paths now looks like:
    # [
    #   [ 'Province', 'EconomicRegion', 'Division', 'ConsolidatedSubdivision', 'Subdivision', 'DisseminationArea', 'DisseminationBlock' ],
    #   [ 'Province', 'ElectoralRegion', 'DisseminationBlock' ],
    #   [ 'MetropolitanArea', 'Tract', 'DisseminationBlock' ],
    #   [ 'MetropolitanArea', 'Subdivision', 'DisseminationArea', 'DisseminationBlock' ]
    # ]
    #
    # At any given pixel, we need X different regions: unique child nodes.
    # For instance, if one pixel is a DisseminationBlock then that's enough
    # info--no need to fill four grids. If one pixel is a Subdivision, then
    # we also need its Tract and ElectoralRegion. These will be in three
    # UTFGrids.
    #
    # In that example, the client needs:
    # * one UTFGrid with the longest chain
    # * one UTFGrid with ElectoralRegion
    # * one UTFGrid with Tract and MetropolitanArea
    # * no fourth grid
    #
    # That is, each grid contains the smallest possible amount of info that
    # the grid before doesn't give.
    #
    # How do we do this? We render all four grids and eliminate equal ones.

    _region_type_sets = map(set, paths)
    return _region_type_sets

if __name__ == '__main__':
    print 'Finding region hierarchies...'
    for l in as_lists():
        print ','.join(l)
