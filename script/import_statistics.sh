#!/bin/sh
#
# This script will import all statistics into the "indicator_region_values"
# table. It can only be run after build_tiles.sh.

`dirname $0`/../statistics_importer/import_2011_popdwe.py `dirname $0`/../db/statistics/2011_92-151_XBB_txt.zip
`dirname $0`/../statistics_importer/calculate_2011_popdwe_rates.py
