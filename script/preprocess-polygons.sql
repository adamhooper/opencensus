-- Run this PostgreSQL script to generate all the tables necessary to start
-- rendering tiles.

-- Requirements: run ogr2ogr on each .shp file from StatsCan, and put them
-- into the "regions" table described in create-regions-table.sql

-- The end result is the following (plus intermediate tables)
-- - region_types(name, description, position)
-- - regions(id, type, uid, name, dissemination_block_uid, ..._uid, geometry,
--           given_area_in_m, polygon_area_in_m, position, subtype)
--   * holds region metadata and canonical geometry
-- - region_polygons_zoom0(id, region_polygon_id, polygon_srid3857)
--   * holds simplified geometries for zoom level 0
-- - region_polygons_zoom1..15
--   * etc
-- - work_queue(zoom_level, region_polygon_id, worker)
--   * when rendering, this is the list of work to do and in progress
-- - region_polygon_tiles(region_polygon_id, zoom_level, tile_row, tile_column,
--                        geometry_srid3857)
--   * will hold rendered pieces of tiles
-- - tiles(zoom_level, tile_row, tile_column, tile_data)
--   * will hold rendered tiles, with metadata and UTFGrids

-- We need to show a "Country" region, for when zoomed way out. Also, it makes
-- a handy parent for Provinces and MetropolitanAreas. This is our root in the
-- hierarchy.
INSERT INTO regions ("type", "uid", name, geometry)
SELECT 'Country', '', 'Canada', ST_Union(geometry)
FROM regions
WHERE type = 'Province';

DROP TABLE IF EXISTS region_types;
CREATE TABLE region_types (
  id SERIAL NOT NULL PRIMARY KEY, -- for Rails
  name VARCHAR NOT NULL,
  description VARCHAR NOT NULL,
  position INT NOT NULL
);
INSERT INTO region_types (name, description, position)
VALUES
('Country', 'Country', 0),
('Province', 'Province', 1),
('ElectoralDistrict', 'Electoral district', 2),
('EconomicRegion', 'Economic region', 3),
('MetropolitanArea', 'Metropolitan area', 4),
('Division', 'Census division', 5),
('ConsolidatedSubdivision', 'Consolidated subdivision', 6),
('Subdivision', 'Census subdivision', 7),
('Tract', 'Census tract', 8),
('DisseminationArea', 'Census dissemination area', 9),
('DisseminationBlock', 'Census dissemination block', 10);

DROP TABLE IF EXISTS region_parents;
CREATE TABLE region_parents (
  region_id INT NOT NULL,
  parent_region_id INT NOT NULL,
  PRIMARY KEY (region_id, parent_region_id)
);

-- template: INSERT INTO region_parents (region_id, parent_region_id) SELECT r.id, p.id FROM regions r INNER JOIN regions p ON p.uid = r.PARENT_UID and p.type = 'PARENT_TYPE' WHERE r.type = 'CHILD_TYPE';
-- "Hierarchy":
-- * Country
--   * MetropolitanArea
--     * Tract
--       * DisseminationArea
--         * DisseminationBlock
--   * Province
--     * ElectoralDistrict
--       * DisseminationBlock
--     * EconomicRegion
--       * Division
--         * ConsolidatedSubdivision
--           * Subdivision
--             * DisseminationArea
--               * DisseminationBlock
-- There's one problem in Ontario in which a Division spans two EconomicRegions
-- but we won't worry about it because it's not in OpenCensus's six cities.
-- (The downside of including it is that our hierarchies get flatter, so we
-- need to send more UTFGrids, which takes more bandwidth.)
INSERT INTO region_parents (region_id, parent_region_id)
      SELECT r.id, p.id FROM regions r, regions p WHERE                                            p.type = 'Country' AND r.type IN ('Province', 'MetropolitanArea')
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.metropolitan_area_uid        AND p.type = 'MetropolitanArea' AND r.type = 'Tract'
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.tract_uid                    AND p.type = 'Tract' AND r.type = 'DisseminationArea'
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.dissemination_area_uid       AND p.type = 'DisseminationArea' AND r.type = 'DisseminationBlock'
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.province_uid                 AND p.type = 'Province' AND r.type IN ('EconomicRegion', 'ElectoralDistrict')
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.electoral_district_uid       AND p.type = 'ElectoralDistrict' AND r.type = 'DisseminationBlock'
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.subdivision_uid              AND p.type = 'Subdivision' AND r.type = 'DisseminationArea'
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.consolidated_subdivision_uid AND p.type = 'ConsolidatedSubdivision' AND r.type = 'Subdivision'
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.division_uid                 AND p.type = 'Division' AND r.type = 'ConsolidatedSubdivision'
UNION SELECT r.id, p.id FROM regions r, regions p WHERE p.uid = r.economic_region_uid          AND p.type = 'EconomicRegion' AND r.type = 'Division';

DROP TABLE IF EXISTS region_polygons;
CREATE TABLE region_polygons (
  id SERIAL PRIMARY KEY,
  region_id INT NOT NULL,
  polygon GEOMETRY NOT NULL
);

INSERT INTO region_polygons (region_id, polygon)
SELECT id, (ST_Dump(geometry)).geom FROM regions;

DELETE FROM region_polygons
WHERE ST_Area(ST_SetSRID(polygon, 4326)::geometry) <= 0;

CREATE INDEX region_polygons_region_id ON region_polygons (region_id);

DROP TABLE IF EXISTS region_polygons_metadata;
CREATE TABLE region_polygons_metadata (
  region_polygon_id INT NOT NULL PRIMARY KEY,
  region_id INT NOT NULL,
  hash CHAR(27) NOT NULL, -- so we won't need to re-compute equal polygons
  -- Our hash isn't perfect. Don't assume polygons are equal IFF hashes are.
  -- Just the one way: equal hashes -> equal polygons
  bounds Box2D NOT NULL,
  area_in_m BIGINT NOT NULL,
  is_island BOOLEAN NOT NULL,
  min_zoom_level INT NOT NULL
);

CREATE EXTENSION pgcrypto;

INSERT INTO region_polygons_metadata
  (region_polygon_id, region_id, hash, bounds, area_in_m, is_island, min_zoom_level)
SELECT id, region_id, LEFT(ENCODE(DIGEST(ST_AsEWKB(polygon), 'sha1'), 'base64'), 27),
  Box2D(polygon), ST_Area(ST_SetSRID(polygon, 4326)::geography), false, -1
FROM region_polygons rp;

DROP EXTENSION pgcrypto;

DELETE FROM region_polygons WHERE id IN (
    SELECT region_polygon_id FROM region_polygons_metadata WHERE area_in_m <= 0);
DELETE FROM region_polygons_metadata WHERE area_in_m <= 0;

CREATE INDEX region_polygons_metadata_region_id
ON region_polygons_metadata (region_id);

CREATE INDEX region_polygons_metadata_hash
ON region_polygons_metadata (hash);

-- This table needn't be perfect, though we hope it is.
DROP TABLE IF EXISTS region_polygon_parents;
CREATE TABLE region_polygon_parents (
  region_polygon_id INT NOT NULL,
  parent_region_polygon_id INT NOT NULL,
  PRIMARY KEY (region_polygon_id, parent_region_polygon_id)
);

INSERT INTO region_polygon_parents
SELECT region_polygon_id, parent_region_polygon_id
FROM (
  SELECT DISTINCT
    rpm1.region_polygon_id AS region_polygon_id,
    rpm2.region_polygon_id AS parent_region_polygon_id,
    RANK() OVER(PARTITION BY rpm1.region_polygon_id, r2.type ORDER BY rpm1.hash = rpm2.hash DESC, rpm2.area_in_m) AS best_match
  FROM region_polygons_metadata rpm1
  INNER JOIN region_parents rp ON rpm1.region_id = rp.region_id
  INNER JOIN region_polygons_metadata rpm2 ON rp.parent_region_id = rpm2.region_id
  INNER JOIN regions r2 ON rpm2.region_id = r2.id
  WHERE ST_Contains(rpm2.bounds, rpm1.bounds)
  AND rpm2.area_in_m >= rpm1.area_in_m) x
WHERE x.best_match = 1;

CREATE INDEX region_polygon_parents_parent_region_polygon_id ON region_polygon_parents (parent_region_polygon_id, region_polygon_id);

-- Calculate "is_island".
-- This is important when deciding which zoom levels to show the polygon on.
-- Islands are obvious on Google Maps, so we display them at lower zoom levels
-- than polygons that aren't surrounded by water.
--
-- The algorithm is this:
-- 1) all polygons of the Country are islands; 
-- 2) polygons of the same size/shape as an island are islands.
UPDATE region_polygons_metadata
SET is_island = TRUE
WHERE region_id IN (SELECT id FROM regions WHERE type = 'Country');

UPDATE region_polygons_metadata
SET is_island = TRUE
WHERE is_island IS FALSE
  AND (bounds, area_in_m) IN (
    SELECT bounds, area_in_m
    FROM region_polygons_metadata
    WHERE is_island IS TRUE);

-- Calculate min_zoom_level *per region*

-- Within a region, either no or all sub-regions will be rendered at a given
-- zoom level. (Within that sub-region, small island polygons can still be
-- skipped. Otherwise we'd have every polygon showing at zoom level 0.)
UPDATE regions SET polygon_area_in_m = 0;
UPDATE regions SET polygon_area_in_m = sums.area_in_m
FROM (
  SELECT region_id, SUM(area_in_m) AS area_in_m
  FROM region_polygons_metadata
  GROUP BY region_id) sums
WHERE sums.region_id = regions.id;

DROP TABLE IF EXISTS region_min_zoom_levels;
CREATE TABLE region_min_zoom_levels (
  region_id INT NOT NULL PRIMARY KEY,
  min_zoom_level INT NOT NULL
);

-- First pass: if a region is big enough, we'll show it
-- "Big enough" is about "400px^2". This will be jiggled around later.
-- meters_per_pixel2 = ((156543.03392804062^2)m / (2^zoom_level)px)^2
-- area_in_m = 400 * meters_per_pixel2 = 400 * 156543.03392804062^2 / (2^zoom_level)^2
-- 2^zoom_level = sqrt(400 * 156543.03392804062 / area_in_m)
-- so zoom_level = log2(sqrt(400 * 156543.03392804062/area_in_m)) (round down)
INSERT INTO region_min_zoom_levels
SELECT
  id,
  CASE
  WHEN type = 'Country' THEN 0
  ELSE
    LEAST(15, FLOOR(LOG(2, SQRT(400 * 156543.03392804062 * 156543.03392804062 / polygon_area_in_m))))
  END
FROM regions
WHERE polygon_area_in_m > 0; -- we won't render 0-size regions

-- If an average sibling region is visible at a certain zoom level, all its
-- siblings should be visible at that zoom level. There's a trade-off: we need
-- either *all* or *no* tracts to show up, but that means we either get lots
-- of tiny tracts or no big tracts. The higher our chosen zoom level, the more
-- we need to zoom in to see tracts (and the less we see tiny tracts). Let's
-- favour tiny tracts a bit, by taking "average" to mean "70th percentile". As
-- in, "if the 70th-percentile-big tract is visible, all are visible."
-- (For 60th percentile, we use (100-70)/100 = 0.3.)
UPDATE region_min_zoom_levels
SET min_zoom_level = medians.zoom
FROM region_parents rp
INNER JOIN (
  SELECT parent_region_id, zooms[FLOOR(ARRAY_LENGTH(zooms, 1)*0.3)+1] AS zoom
  FROM (
    SELECT parent_region_id, ARRAY_AGG(zoom) AS zooms
    FROM (
      SELECT rp2.parent_region_id, rmzl2.min_zoom_level AS zoom
      FROM region_parents rp2
      INNER JOIN region_min_zoom_levels rmzl2
        ON rp2.region_id = rmzl2.region_id
      ORDER BY rp2.parent_region_id, rmzl2.min_zoom_level) x1
    GROUP BY parent_region_id) x2
  ) medians ON rp.parent_region_id = medians.parent_region_id
WHERE rp.region_id = region_min_zoom_levels.region_id;

-- Calculate min_zoom_level *per polygon*

-- If a region is to be rendered, we should render its polygons, UNLESS
-- they're too small. This happens in the case of islands: Quebec has lots of
-- islands we don't want to render until way later. As long as we aren't
-- rendering the polygon's parent-region polygons, we don't need to render
-- this one. So we:
-- 1) copy from region_min_zoom_levels;
-- 2) set a higher zoom level for small islands; and
-- 3) make sure a polygon's zoom level is never greater than children polygons'
--    (which may not be islands) by modifying the children.

-- Bring min_zoom_level to metadata table, to speed things up
UPDATE region_polygons_metadata
SET min_zoom_level = rmzl.min_zoom_level
FROM region_min_zoom_levels rmzl
WHERE rmzl.region_id = region_polygons_metadata.region_id;

-- Islands show up when they're 36px^2 (6*6)
UPDATE region_polygons_metadata
SET min_zoom_level = LEAST(
  15,
  GREATEST(
    min_zoom_level,
    CEIL(LOG(2, SQRT(36 * 156543.03392804062 * 156543.03392804062 / area_in_m)))
  ))
WHERE is_island IS TRUE;

CREATE OR REPLACE FUNCTION propagate_min_zoom_levels() RETURNS void AS $$
BEGIN
  FOR i IN 1..6 LOOP
    -- Province-level islands propagate zoom levels to EconomicRegion
    -- Next: EconomicRegion islands propagate to Division
    -- etc. The deepest hierarchy is 7 levels, so 6 propagations
    UPDATE region_polygons_metadata child
    SET min_zoom_level = GREATEST(child.min_zoom_level, parent.min_zoom_level)
    FROM region_polygon_parents rpp
    INNER JOIN region_polygons_metadata parent
      ON rpp.parent_region_polygon_id = parent.region_polygon_id
    WHERE rpp.region_polygon_id = child.region_polygon_id
    AND child.min_zoom_level < parent.min_zoom_level;
  END LOOP;
END;
$$ LANGUAGE plpgsql;
SELECT propagate_min_zoom_levels();
DROP FUNCTION propagate_min_zoom_levels();

-- Set up simplified, filtered tables for working with
-- It's quicker to compute these all at once than to run these functions on
-- every select.
-- "allowed_error" is 0.5px.
-- meters_per_tile = 20037508.342789244 / (2^(zoom_level-1))
-- meters_per_pixel = 20037508.342789244 / (2^(zoom_level-1)) / 256
-- meters_per_pixel = 20037508.342789244 / (2^(zoom_level+7))

DROP TABLE IF EXISTS work_queue;
CREATE TABLE work_queue (
  zoom_level INT NOT NULL,
  region_polygon_id INT NOT NULL,
  worker INT,
  PRIMARY KEY (zoom_level, region_polygon_id)
);
CREATE INDEX work_queue_worker ON work_queue (worker);

CREATE OR REPLACE FUNCTION generate_region_polygons_zooms() RETURNS void AS $$
BEGIN
  FOR i IN 0..15 LOOP
    --region_polygons_zoom0 .. region_polygons_zoom15
    EXECUTE
    'DROP TABLE IF EXISTS ' || QUOTE_IDENT('region_polygons_zoom' || i);

    EXECUTE
    'CREATE TABLE ' || QUOTE_IDENT('region_polygons_zoom' || i) || ' ('
      || 'region_polygon_id INT NOT NULL PRIMARY KEY,'
      || 'polygon_srid3857 GEOMETRY NOT NULL'
      || ')';

    EXECUTE
    'INSERT INTO ' || QUOTE_IDENT('region_polygons_zoom' || i) || ' '
      || 'SELECT id, ST_MakeValid('
      || '  ST_Buffer('
      || '    ST_SimplifyPreserveTopology('
      || '      ST_Transform(ST_SetSRID(polygon, 4326), 3857),'
      || '      ' || (0.5 * 20037508.342789244 / POWER(2, i + 7))
      || '    ),'
      || '  0)'
      || ') '
      || 'FROM region_polygons '
      || 'WHERE id IN ('
      ||   'SELECT region_polygon_id '
      ||   'FROM region_polygons_metadata '
      ||   'WHERE min_zoom_level <= ' || i
      || ')';

    EXECUTE
    'INSERT INTO work_queue (zoom_level, region_polygon_id) '
    || 'SELECT ' || i || ', region_polygon_id '
    || 'FROM ' || QUOTE_IDENT('region_polygons_zoom' || i);
  END LOOP;
END;
$$ LANGUAGE plpgsql;
SELECT generate_region_polygons_zooms();
DROP FUNCTION generate_region_polygons_zooms();

CLUSTER work_queue USING work_queue_pkey;
VACUUM ANALYZE work_queue;

DROP TABLE IF EXISTS region_polygon_tiles;
CREATE TABLE region_polygon_tiles (
  region_polygon_id INT NOT NULL,
  zoom_level INT NOT NULL,
  tile_row INT NOT NULL,
  tile_column INT NOT NULL,
  geometry_srid3857 GEOMETRY NOT NULL,
  PRIMARY KEY (zoom_level, tile_row, tile_column, region_polygon_id)
);

CREATE INDEX region_polygon_tiles_region_polygon_id ON region_polygon_tiles (region_polygon_id);
