#!/usr/bin/env python

import distutils.util
import os
import re
import struct
import sys

import cairo

from utf_grid import UTFGrid

def _ints_to_unicode(data, offset, n_ints):
    row_format = 'Hxx' * n_ints
    shorts = struct.unpack_from(row_format, data, offset)
    # I'm no good at big/little endianness. I don't know what the image
    # endianness is, or the string endianness. But this all seems to
    # work on x86-64.
    # XXX this code assumes we're always below U+D7FF.
    return struct.pack('%dH' % n_ints, *shorts).decode('UTF-16')

sys.path.append('%s/ext/build/lib.%s-%d.%d' % (os.path.dirname(__file__), distutils.util.get_platform(), sys.version_info.major, sys.version_info.minor))
try:
    import speedups
    _argb256_to_unicode = speedups.argb256_to_unicode
except ImportError:
    print 'Running WITHOUT the "speedups" module.'
    print 'For faster operation, run "python setup.py build" in the ext/ directory and then run this program again.'

    def _argb256_to_unicode(data, offset):
        return _ints_to_unicdoe(data, offset, 256)
sys.path.pop()

# https://github.com/mapbox/mbtiles-spec/blob/master/1.1/utfgrid.md
class UTFGridBuilder:
    def __init__(self, tile):
        self.meters_per_half_map = 20037508.34
        self.width = tile.width
        self.height = tile.height

        # We'll draw on a regular, non-antialiased image: color 0, color 1, etc.
        # Each color in the image is a UTFGrid-encoded id (endianness: argb)
        self.image = cairo.ImageSurface(cairo.FORMAT_RGB24, self.width, self.height)
        self.image_context = cairo.Context(self.image)
        self.image_context.set_antialias(cairo.ANTIALIAS_NONE)

        self.reset_to_new_tile(tile)

    def reset_to_new_tile(self, tile):
        self.keys = []

        self.meters_per_pixel = 2 * self.meters_per_half_map / self.width / 2 ** tile.coord.zoom
        self.pixels_per_meter = 1 / self.meters_per_pixel

        self.left = tile.coord.column * self.width # in absolute pixels from top-left
        self.top = tile.coord.row * self.height # in absolute pixels from top-left

        self._set_new_key('')
        self.image_context.rectangle(0, 0, self.width, self.height)
        self.image_context.fill()

    def _set_new_key(self, key):
        next_id = len(self.keys)

        encoded_id = self._encode_id(next_id)

        hex_code = hex(encoded_id)[2:].zfill(6)

        r = int(hex_code[0:2], 16) / 255.0
        g = int(hex_code[2:4], 16) / 255.0
        b = int(hex_code[4:6], 16) / 255.0

        self.image_context.set_source_rgb(r, g, b)

        self.keys.append(key)

    def _draw_path(self, svg_path):
        x_coord = None
        func = None

        # e.g. M 0 0 L 0 -1 1 -1 1 0 Z
        for rule in re.split('[ ,;]', svg_path):
            if rule == 'M':
                func = self.image_context.move_to
            elif rule == 'L':
                func = self.image_context.line_to
            elif rule == 'Z':
                self.image_context.close_path()
            elif x_coord is None:
                x_coord = (float(rule) + self.meters_per_half_map) * self.pixels_per_meter - self.left
            else:
                y_coord = (float(rule) + self.meters_per_half_map) * self.pixels_per_meter - self.top
                func(x_coord, y_coord)
                x_coord = None # but leave "func" alone

        self.image_context.fill()

    def add(self, svg_path, key):
        self._set_new_key(key)
        self._draw_path(svg_path)

    def add_cairo_path(self, cairo_path, key):
        self._set_new_key(key)
        self.image_context.append_path(cairo_path)
        self.image_context.fill()

    def _encode_id(self, id):
        encoded_id = id + 32
        if encoded_id >= 34: encoded_id += 1
        if encoded_id >= 92: encoded_id += 1
        return encoded_id

    def _calculate_grid(self):
        rows = []

        stride = self.image.get_stride()
        data = self.image.get_data()

        if self.width == 256:
            _data_to_unicode = _argb256_to_unicode
        else:
            def _data_to_unicode(data, offset):
                return _ints_to_unicode(data, offset, self.width)

        offset = 0
        # Ints will be 0xff000000, 0xff000001, etc: 0xffRRGGBB
        # Limit outselves to 16-bit ... which is UTFGrid spec anyway

        for y in xrange(0, self.height):
            ustr = _data_to_unicode(data, offset)
            rows.append(ustr)
            offset += stride

        return rows

    def get_utfgrid(self):
        grid = self._calculate_grid()
        return UTFGrid(grid, self.keys)
