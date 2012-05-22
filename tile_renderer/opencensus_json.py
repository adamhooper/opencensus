#!/usr/bin/env python

import json

def encode(obj):
    return json.dumps(obj, ensure_ascii=False, check_circular=False, separators=(',', ':'))

def decode(obj):
    return json.loads(obj)
