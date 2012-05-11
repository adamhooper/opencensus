-- Run this PostgreSQL script to prepare for UTFGrid generation.

-- Requirements: regions, region_polygon_tiles

CLUSTER region_polygon_tiles USING region_polygon_tiles_pkey; -- speedup

DROP TABLE IF EXISTS region_type_parents;
CREATE TABLE region_type_parents (
  region_type VARCHAR NOT NULL,
  parent_region_type VARCHAR NOT NULL,
  PRIMARY KEY (region_type, parent_region_type)
);
INSERT INTO region_type_parents (region_type, parent_region_type)
VALUES
('DisseminationBlock', 'DisseminationArea'),
('DisseminationBlock', 'ElectoralDistrict'),
('DisseminationArea', 'Subdivision'),
('DisseminationArea', 'Tract'),
('Tract', 'MetropolitanArea'),
('Subdivision', 'ConsolidatedSubdivision'),
('Subdivision', 'EconomicRegion'),
('ConsolidatedSubdivision', 'Division'),
('Division', 'Province'),
('ElectoralDistrict', 'Province'),
('EconomicRegion', 'Province'),
('Province', 'Country'),
('MetropolitanArea', 'Country');

DROP TABLE IF EXISTS utfgrids;
CREATE TABLE utfgrids (
  zoom_level INT NOT NULL,
  tile_row INT NOT NULL,
  tile_column INT NOT NULL,
  -- Because there's no hierarchy, we have several grids per tile
  utfgrids TEXT NOT NULL,
  PRIMARY KEY (zoom_level, tile_row, tile_column)
);

DROP TABLE IF EXISTS work_queue2;
CREATE TABLE work_queue2 (
  zoom_level INT NOT NULL,
  tile_row INT NOT NULL,
  tile_column INT NOT NULL,
  worker INT DEFAULT NULL,
  PRIMARY KEY (zoom_level, tile_row, tile_column)
);
INSERT INTO work_queue2 (zoom_level, tile_row, tile_column)
SELECT DISTINCT zoom_level, tile_row, tile_column
FROM region_polygon_tiles;
CREATE INDEX work_queue2_worker ON work_queue2 (worker);

-- For the first time, with UTFGrid processing, we need to draw smaller
-- regions on top of larger ones. This is subjective (should a MetropolitanArea
-- draw over an EconomicRegion?) but this ordering seems reasonable.
UPDATE regions SET position = CASE type
  WHEN 'Country' THEN 1
  WHEN 'Province' THEN 2
  WHEN 'EconomicRegion' THEN 3
  WHEN 'ElectoralDistrict' THEN 4
  WHEN 'MetropolitanArea' THEN 5
  WHEN 'Division' THEN 6
  WHEN 'ConsolidatedSubdivision' THEN 7
  WHEN 'Subdivision' THEN 8
  WHEN 'Tract' THEN 9
  WHEN 'DisseminationArea' THEN 10
  WHEN 'DisseminationBlock' THEN 11
  ELSE NULL
  END;
CREATE INDEX regions_utfgrid_data ON regions (id, type, uid, position);
