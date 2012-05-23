DELETE FROM indicator_region_values WHERE indicator_id = (SELECT id FROM indicators WHERE key = 'gro');

INSERT INTO indicator_region_values (region_id, indicator_id, value_float, note)
SELECT
  i1.region_id,
  (SELECT id FROM indicators WHERE key = 'gro') AS indicator_id,
  100.0 * (i1.value_integer::FLOAT / i2.value_integer::FLOAT - 1.0) AS growth,
  COALESCE(i1.note, i2.note) AS note
FROM indicator_region_values i1
INNER JOIN indicator_region_values i2
  ON i1.region_id = i2.region_id
  AND i2.indicator_id = (SELECT id FROM indicators WHERE key = 'pop2006')
WHERE i1.indicator_id = (SELECT id FROM indicators WHERE key = 'pop')
  AND i2.value_integer <> 0;
