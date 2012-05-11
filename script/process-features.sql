-- Run this PostgreSQL script to generate the tile_features table.

-- Requirements: regions and region_polygon_tiles. Be sure the "position"
-- column is set on the regions table.

DROP TABLE IF EXISTS tile_features;
CREATE TABLE tile_features (
  zoom_level INT NOT NULL,
  tile_row INT NOT NULL,
  tile_column INT NOT NULL,
  region_id INT NOT NULL,
  json_id VARCHAR NOT NULL,
  region_name VARCHAR NOT NULL,
  position INT NOT NULL, -- for ordering smaller in front of larger
  geojson_geometry TEXT NOT NULL,
  PRIMARY KEY (zoom_level, tile_row, tile_column, region_id)
);

-- Number of decimals used in ST_AsGeoJSON() is important, because it saves
-- lots of space.
--
-- max-error-in-px = 0.5px # one-dimensional
-- deg-per-tile = 170.0 / 2^zoom # north-south
-- deg-per-px = deg-per-tile / 256
-- max-error-in-deg = max-error-in-px * deg-per-px
--   = 170.0 / 2 ^ (zoom + 8)
-- min-precision-decimals = base-decimals - log10(max-error-in-deg)
--   = ceil(3 - log10(170.0 / 2 ^ (zoom + 8)))
INSERT INTO tile_features
  (zoom_level, tile_row, tile_column,
    region_id, region_name, json_id, position, geojson_geometry)
SELECT
  rpt.zoom_level,
  rpt.tile_row,
  rpt.tile_column,
  rpm.region_id,
  r.name,
  CONCAT(r.type, '-', r.uid) AS json_id,
  r.position AS position,
  ST_ASGeoJSON(ST_Collect(ST_Transform(ST_SetSRID(rpt.geometry_srid3857, 3857), 4326)),
    CEIL(3 - LOG(170.0 / (2.0 ^ (zoom_level + 8)))) AS geojson
FROM region_polygon_tiles rpt
INNER JOIN region_polygons_metadata rpm
  ON rpt.region_polygon_id = rpm.region_polygon_id
INNER JOIN regions r ON rpm.region_id = r.id
GROUP BY r.id;

CLUSTER tile_features USING tile_features_pkey;
