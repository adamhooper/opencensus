#!/usr/bin/env python2.7

import math

import shapely.wkb
from shapely.wkb import loads as _load_polygon_wkb
from shapely.wkb import dumps as _dump_polygon_wkb
from shapely.geometry import box as _box

from coord import Coord as _Coord
from tile import Tile as _Tile

_PADDING_IN_PX = 4

"""Slices a polygon at a certain zoom level.
"""
class RegionPolygonAtZoomLevel:
    """Creates a new region polygon from database data

    zoom_level: the zoom level
    polygon_wkb: the well-known binary representation of a polygon,
                 simplified and in EPSG:3857 spherical-Mercator projection.
    """
    def __init__(self, pixels_per_tile_side, zoom_level, polygon_wkb):
        self.pixels_per_tile_side = pixels_per_tile_side
        self.zoom_level = zoom_level
        self.polygon = _load_polygon_wkb(polygon_wkb)
        (self._minx, self._miny, self._maxx, self._maxy) = self.polygon.bounds
        self.meters_per_tile = 20037508.342789244 / 2**(zoom_level-1)
        self.meters_per_pixel = self.meters_per_tile / pixels_per_tile_side
        self.padding = _PADDING_IN_PX * self.meters_per_pixel
        self.origin_offset = 20037508.342789244
        self.tiles_per_world_side = 2 ** zoom_level

    """Yields every tile row this polygon uses.

    The polygon doesn't intersect every row/column combination, but it does
    intersect every column.
    """
    def get_tile_rows(self):
        first = int(
            (self.origin_offset - self._maxy - self.padding)
            / self.meters_per_tile)
        if first < 0: first = 0
        last = int(math.ceil(
            (self.origin_offset - self._miny + self.padding)
            / self.meters_per_tile))
        if last > self.tiles_per_world_side: last = self.tiles_per_world_side

        return xrange(first, last + 1)

    """Yields every tile column this polygon uses.

    The polygon doesn't intersect every row/column combination, but it does
    intersect every column.
    """
    def get_tile_columns(self):
        first = int(
            (self.origin_offset + self._minx - self.padding)
            / self.meters_per_tile)
        if first < 0: first = 0
        last = int(math.ceil(
            (self.origin_offset + self._maxx + self.padding)
            / self.meters_per_tile))
        if last > self.tiles_per_world_side: last = self.tiles_per_world_side

        return xrange(first, last + 1)

    def get_row_slices(self):
        for row in self.get_tile_rows():
            top = self.origin_offset + self.padding \
                - (row * self.meters_per_tile)
            bottom = self.origin_offset - self.padding \
                - ((row + 1) * self.meters_per_tile)
            clip = _box(self._minx, top, self._maxx, bottom)
            clipped = clip.intersection(self.polygon)
            yield (row, clipped)

    def get_tile_slices(self):
        for row, polygon in self.get_row_slices():
            for column in self.get_tile_columns():
                left = column * self.meters_per_tile - self.padding \
                    - self.origin_offset
                right = (column + 1) * self.meters_per_tile + self.padding \
                    - self.origin_offset
                clip = _box(left, self._miny, right, self._maxy)

                clipped = clip.intersection(polygon)

                if clipped:
                    wkb = _dump_polygon_wkb(clipped)
                    yield (row, column, wkb)
