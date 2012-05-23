DELETE FROM indicator_region_values WHERE indicator_id IN (SELECT id FROM indicators WHERE key IN ('popdens', 'dwedens', 'popdwe'));

INSERT INTO indicator_region_values (region_id, indicator_id, value_float, note)
SELECT
  i.region_id,
  (SELECT id FROM indicators WHERE key = 'popdens') AS indicator_id,
  i.value_integer::FLOAT / (CASE WHEN r.given_area_in_m > 0 THEN r.given_area_in_m::FLOAT / 1000000 WHEN r.polygon_area_in_m > 0 THEN r.polygon_area_in_m::FLOAT / 1000000 ELSE 1.0 END) AS density,
  i.note AS note
FROM indicator_region_values i
INNER JOIN regions r ON i.region_id = r.id
WHERE indicator_id = (SELECT id FROM indicators WHERE key = 'pop');

INSERT INTO indicator_region_values (region_id, indicator_id, value_float, note)
SELECT
  i.region_id,
  (SELECT id FROM indicators WHERE key = 'dwedens') AS indicator_id,
  i.value_integer::FLOAT / (CASE WHEN r.given_area_in_m > 0 THEN r.given_area_in_m::FLOAT / 1000000 WHEN r.polygon_area_in_m > 0 THEN r.polygon_area_in_m::FLOAT / 1000000 ELSE 1.0 END) AS density,
  i.note AS note
FROM indicator_region_values i
INNER JOIN regions r ON i.region_id = r.id
WHERE indicator_id = (SELECT id FROM indicators WHERE key = 'dwe');

INSERT INTO indicator_region_values (region_id, indicator_id, value_float, note)
SELECT
  i1.region_id,
  (SELECT id FROM indicators WHERE key = 'popdwe') AS indicator_id,
  i1.value_integer::FLOAT / i2.value_integer::FLOAT AS popdwe,
  COALESCE(i1.note, i2.note) AS note
FROM indicator_region_values i1
INNER JOIN indicator_region_values i2
  ON i1.region_id = i2.region_id
  AND i2.indicator_id = (SELECT id FROM indicators WHERE key = 'dwe')
WHERE i1.indicator_id = (SELECT id FROM indicators WHERE key = 'pop')
AND i2.value_integer <> 0;
