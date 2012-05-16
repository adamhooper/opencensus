-- Run this PostgreSQL script to generate the tile_features table.

-- Requirements: regions and region_polygon_tiles. Be sure the "position"
-- column is set on the regions table.

DROP TABLE IF EXISTS feature_tiles;
CREATE TABLE feature_tiles (
  zoom_level INT NOT NULL,
  tile_row INT NOT NULL,
  tile_column INT NOT NULL,
  region_id INT NOT NULL,
  json_id VARCHAR NOT NULL,
  region_name VARCHAR DEFAULT NULL,
  position INT NOT NULL, -- for ordering smaller in front of larger
  geojson_geometry TEXT NOT NULL,
  PRIMARY KEY (zoom_level, tile_row, tile_column, region_id)
);

-- Number of decimals used in ST_AsGeoJSON() is important, because it saves
-- lots of space.
--
-- max-error-in-px = 0.5px # one-dimensional
-- m-per-tile = 20037508.342789244 / 2^(zoom-1)
-- m-per-px = m-per-tile / 256 = 20037508.342789244 / 2^(zoom+7)
-- max-error-in-m = max-error-in-px * m-per-px
--   = 0.5 * 20037508.342789244 / 2^(zoom+7)
-- max-error-in-m is 4.77731426782 when zoom = 15. That means integer
-- precision in EPSG3857 will always suffice. So precision = 0
INSERT INTO feature_tiles
  (zoom_level, tile_row, tile_column,
    region_id, region_name, json_id, position, geojson_geometry)
SELECT
  rpt.zoom_level,
  rpt.tile_row,
  rpt.tile_column,
  rpm.region_id,
  r.name,
  CONCAT(r.type, '-', COALESCE(r.uid, '')) AS json_id,
  r.position AS position,
  ST_AsGeoJSON(ST_Collect(rpt.geometry_srid3857), 0) AS geojson
FROM region_polygon_tiles rpt
INNER JOIN region_polygons_metadata rpm
  ON rpt.region_polygon_id = rpm.region_polygon_id
INNER JOIN regions r ON rpm.region_id = r.id
GROUP BY
  rpt.zoom_level, rpt.tile_row, rpt.tile_column, rpm.region_id, r.name, r.type, r.uid,
  r.position
ORDER BY rpt.zoom_level, rpt.tile_row, rpt.tile_column, r.position, rpm.region_id;

CLUSTER feature_tiles USING feature_tiles_pkey;
