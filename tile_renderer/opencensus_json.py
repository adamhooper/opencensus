#!/usr/bin/env python

import json

from utf_grid import UTFGrid as _UTFGrid
from tile_data import TileData as _TileData

def _utfgrids_to_object_list(grids):
    return map(lambda g: { 'grid': g.grid, 'keys': g.keys }, grids)

def encode(obj):
    if isinstance(obj, _TileData):
        obj = {
            'type': 'FeatureCollection',
            'features': obj.features,
            'utfgrids': _utfgrids_to_object_list(obj.utfgrids())
        }
    return json.dumps(obj, ensure_ascii=False, check_circular=False, separators=(',', ':'))

def _decode_object(obj):
    if 'grid' in obj and 'keys' in obj:
        return _UTFGrid(obj['grid'], obj['keys'])

    if 'type' in obj and obj['type'] == 'FeatureCollection' and 'features' in obj and 'utfgrids' in obj:
        return _TileData(obj['features'], obj['utfgrids'])

    return obj

def decode(obj):
    return json.loads(obj, object_hook=_decode_object)
