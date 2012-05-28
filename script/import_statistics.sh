#!/bin/sh
#
# This script will import all statistics into the "indicator_region_values"
# table. It can only be run after build_tiles.sh. It shouldn't take longer than
# 10-30 minutes.

POSTGIS_SQL_FILE=`pg_config --sharedir`/contrib/postgis-2.0/postgis.sql
POSTGIS_SQL_FILE2=`pg_config --sharedir`/contrib/postgis-2.0/spatial_ref_sys.sql
PGPASSFILE=`dirname $0`/dot-pgpass
PGDATABASE=opencensus_dev
PGHOST=localhost
PGUSER=opencensus_dev
PGPASS=opencensus_dev

rm -f $PGPASSFILE

## Set up login (for remainder of the script)
echo "$PGHOST:*:$PGDATABASE:$PGUSER:$PGPASS" > $PGPASSFILE
chmod 0600 $PGPASSFILE
export PGHOST
export PGUSER
export PGDATABASE
export PGPASSFILE

## Build stats schema
psql -f `dirname $0`/create-statistics-schema.sql

`dirname $0`/../statistics_importer/import_2011_popdwe.py `dirname $0`/../db/statistics/2011_92-151_XBB_txt.zip
`dirname $0`/../statistics_importer/import_2006_agesex.py `dirname $0`/../db/statistics/94-575-XCB2006005.ZIP

psql -f `dirname $0`/../statistics_importer/calculate-2011-popdwe-rates.sql
`dirname $0`/../statistics_importer/calculate_agesex_averages.py
