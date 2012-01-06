#!/usr/bin/env python

import re
import struct

import cairo

# https://github.com/mapbox/mbtiles-spec/blob/master/1.1/utfgrid.md
class UTFGridBuilder:
    def __init__(self, width, height, coord):
        self.keys = []
        self.width = width
        self.height = height

        self.meters_per_half_map = 20037508.34
        self.meters_per_pixel = 2 * self.meters_per_half_map / self.width / 2 ** coord.zoom
        self.pixels_per_meter = 1 / self.meters_per_pixel

        self.left = coord.column * self.width # in absolute pixels from top-left
        self.top = coord.row * self.height # in absolute pixels from top-left

        # We'll draw on a regular, non-antialiased image: color 0, color 1, etc.
        # Each color in the image is a UTFGrid-encoded id (endianness: argb)
        self.image = cairo.ImageSurface(cairo.FORMAT_RGB24, width, height)
        self.image_context = cairo.Context(self.image)
        self.image_context.set_antialias(cairo.ANTIALIAS_NONE)

        self._set_new_key('')
        self.image_context.rectangle(0, 0, width, height)
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

    def add(self, svg_path, key):
        self._set_new_key(key)

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

    def _encode_id(self, id):
        encoded_id = id + 32
        if encoded_id >= 32: encoded_id += 1
        if encoded_id >= 92: encoded_id += 1
        return encoded_id

    def _get_utfgrid_grid(self):
        rows = []

        stride = self.image.get_stride()
        data = self.image.get_data()

        start = 0
        row_format = '%dI' % self.width
        row_size = self.width * 4
        for y in xrange(0, self.height):
            ints = struct.unpack(row_format, data[start:start + row_size])
            # Will be 0xff000000, 0xff000001, etc: 0xffRRGGBB
            unichars = [ unichr(x & 0xffffff) for x in ints ]
            rows.append(u''.join(unichars))
            start += stride

        return rows

    def get_utfgrid_data(self):
        return {
            'grid': self._get_utfgrid_grid(),
            'keys': self.keys
        }
