#!/bin/sh
#
# This script will take days or weeks to run. It automates all the work of
# importing and pre-processing tiles. At the end of it, there will be a
# "tiles" table filled with pseudo-JSON, plus every other table necessary for
# the Rails and Python servers to work as expected.
#
# The only thing this script won't do is import actual statistics.

POSTGIS_SQL_FILE=`pg_config --sharedir`/contrib/postgis-2.0/postgis.sql
POSTGIS_SQL_FILE2=`pg_config --sharedir`/contrib/postgis-2.0/spatial_ref_sys.sql
PGPASSFILE=`dirname $0`/dot-pgpass
PGDATABASE=opencensus_dev
PGHOST=localhost
PGUSER=opencensus_dev
PGPASS=opencensus_dev

rm -qf $PGPASSFILE

## Create database
psql --quiet -c "CREATE USER $PGUSER WITH PASSWORD '$PGPASS'"
createdb --owner=opencensus_dev opencensus_dev

## Set up login (for remainder of the script)
echo "$PGHOST:*:$PGDATABASE:$PGUSER:$PGPASS" > $PGPASSFILE
chmod 0600 $PGPASSFILE
export PGHOST
export PGUSER
export PGDATABASE
export PGPASSFILE

## Initialize PostGIS
psql -f $POSTGIS_SQL_FILE
psql -f $POSTGIS_SQL_FILE2

## Move regions into one "regions" table
psql -f `dirname $0`/create-regions-table.sql

## Import regions
for f in $(ls $(dirname $0)/../db/shapes/*.shp); do
	echo "WHOOPS! Need to run ogr2ogr on $f but haven't written this bit out yet"
	exit 1
	echo "WHOOPS! Need to move from the ogr2ogr table into the regions table"
	exit 1
done

## Prepare tiles for rendering
psql -f `dirname $0`/preprocess-polygons.sql

## Render polygon tiles
`dirname $0`/../tile_renderer/render_region_polygon_tiles.py

## Build UTFGrids
psql -f `dirname $0`/prepare-utfgrids.sql
`dirname $0`/../tile_renderer/render_utfgrids.py

## Turn those into "tiles", without stats
`dirname $0`/../tile_renderer/agglomerate-region_polygon_tiles.py

## Build stats schema
psql -f `dirname $0`/create-statistics-schema.sql
