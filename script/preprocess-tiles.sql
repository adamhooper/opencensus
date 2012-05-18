-- Creates the "tiles" table.

-- Requires: feature_tiles, utfgrids, region_parents
-- Creates intermediate tables: region_parents_json, feature_json_tiles, feature_collection_tiles

-- Running time: ~45s
DROP TABLE IF EXISTS region_parents_json;
CREATE TABLE region_parents_json (
  region_id INT NOT NULL PRIMARY KEY,
  parents_json VARCHAR NOT NULL
);
INSERT INTO region_parents_json (region_id, parents_json)
SELECT c.id, CONCAT('[', COALESCE(STRING_AGG(CONCAT('"', p.type, '-', p.uid, '"'), ','), ''), ']')
FROM regions c
LEFT JOIN region_parents rp ON c.id = rp.region_id
LEFT JOIN regions p ON rp.parent_region_id = p.id
GROUP BY c.id;
VACUUM ANALYZE region_parents_json;

DROP TABLE IF EXISTS work_queue3;
CREATE TABLE work_queue3 (
  zoom_level INT NOT NULL,
  tile_row INT NOT NULL,
  tile_column INT NOT NULL,
  worker INT DEFAULT NULL,
  PRIMARY KEY (zoom_level, tile_row, tile_column)
);
INSERT INTO work_queue3
SELECT zoom_level, tile_row, tile_column FROM utfgrids;
CREATE INDEX work_queue3_worker ON work_queue3 (worker);

DROP TABLE IF EXISTS tiles;
CREATE TABLE tiles (
  zoom_level INT NOT NULL,
  tile_row INT NOT NULL,
  tile_column INT NOT NULL,
  tile_data TEXT NOT NULL,
  PRIMARY KEY (zoom_level, tile_row, tile_column)
);
