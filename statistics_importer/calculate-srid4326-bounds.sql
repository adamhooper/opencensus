DELETE FROM indicator_region_values WHERE indicator_id = (SELECT id FROM indicators WHERE key = 'bounds');

INSERT INTO indicator_region_values (region_id, indicator_id, value_string)
SELECT
  id,
  (SELECT id FROM indicators WHERE key = 'bounds'),
  ST_XMin(bbox)::VARCHAR || ',' || ST_YMin(bbox)::VARCHAR || ',' || ST_XMax(bbox)::VARCHAR || ',' || ST_YMax(bbox)::VARCHAR
FROM (
  SELECT id, ST_Transform(ST_SetSRID(geometry, 4326), 4326) AS bbox
  FROM regions
) regions;

