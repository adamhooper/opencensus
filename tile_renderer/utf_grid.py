#!/usr/bin/env

import json
import re

class UTFGrid:
    def __init__(self, grid, keys):
        self.height = len(grid)
        self.width = len(grid[0])
        self.keys = keys
        self.grid = grid

    def _simplify_grid(self):
        # Return a one-char grid if there's only one char
        first_char = self.grid[0][0]
        regex = '^%s*$' % re.escape(first_char)
        if re.match(regex, u''.join(self.grid)):
            self.grid = [ first_char ]
            self.height = 1
            self.width = 1

    # When drawing, we sometimes overwrite entire regions. For instance, a
    # Province is almost always covered up by EconomicRegions. This method
    # eliminates keys that don't show up on the map.
    #
    # The advantage is in the grid: if we stick with under 100 regions
    # per tile, we stay in ASCII so the pixels take only one char each.
    def _simplify_keys(self):
        new_keys = []
        translations = {}

        grid_as_unistr = u''.join(self.grid)

        key_index = 0
        old_char = ord(' ')
        new_char = ord(' ')

        for key in self.keys:
            if unichr(old_char) in grid_as_unistr:
                translations[old_char] = new_char
                new_keys.append(key)
                new_char += 1
                if new_char == 34: new_char += 1
                elif new_char == 92: new_char += 1
            old_char += 1
            if old_char == 34: old_char += 1
            elif old_char == 92: old_char += 1

        self.grid = [ s.translate(translations) for s in self.grid ]
        self.keys = new_keys

    # Removes keys that aren't in use, and shrinks the grid to 1x1 if the
    # whole tile is zoomed in on a single region.
    def simplify(self):
        self._simplify_grid()
        self._simplify_keys()
