#!/usr/bin/env python

import json

from utf_grid import UTFGrid as _UTFGrid
from tile_data import TileData as _TileData

class _Encoder(json.JSONEncoder):
    def __init__(self):
        super(_Encoder, self).__init__(ensure_ascii=False, check_circular=False, separators=(',', ':'))

    def default(self, obj):
        if isinstance(obj, _UTFGrid):
            return { 'grid': obj.grid, 'keys': obj.keys }
        elif isinstance(obj, _TileData):
            return { 'type': 'FeatureCollection', 'features': obj.features, 'utfgrids': obj.utfgrids() }
        else:
            raise TypeError('Invalid object type for JSON encoding: %r' % obj)

_encoder = _Encoder()

def encode(obj):
    return _encoder.encode(obj)

def _decode_object(obj):
    if 'grid' in obj and 'keys' in obj:
        return UTFGrid(obj['grid'], obj['keys'])

    if 'type' in obj and 'features' in obj and 'utfgrids' in obj:
        return TileData(obj, 'features', 'utfgrids')

    return obj

def decode(obj):
    return json.loads(obj, object_hook=_decode_object)
