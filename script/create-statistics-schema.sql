-- Run this PostgreSQL script to generate all the tables necessary to
-- import and serve statistics.

-- The end result is the following:

-- - indicators(id, key, name, unit, description, value_type, buckets)
--   * holds indicator metadata
-- - indicator_region_values (region_id, indicator_id, value_integer,
--                            value_float, value_string, note)
--   * holds actual indicators

DROP TABLE IF EXISTS indicators;
CREATE TABLE indicators (
  id SERIAL PRIMARY KEY,
  key VARCHAR NOT NULL,
  name VARCHAR NOT NULL,
  unit VARCHAR NOT NULL,
  description VARCHAR NOT NULL,
  value_type VARCHAR NOT NULL,
  buckets VARCHAR -- NULL when it isn't a mappable stat
);
INSERT INTO indicators (key, name, unit, description, value_type, buckets)
VALUES
('pop', 'Population', '', '', 'integer', NULL),
('dwe', 'Dwellings', '', '', 'integer', NULL),
('occdwe', 'Occupied dwellings', '', '', 'integer', NULL),
('popdens', 'Population density', 'people per km²', '', 'float',
  '[{"max":5,"color":"#edf8fb","label":"up to 5 people per km²"},' ||
  '{"max":20,"color":"#ccece6"},' ||
  '{"max":100,"color":"#99d8c9"},' ||
  '{"max":500,"color":"#66c2a4"},' ||
  '{"max":1000,"color":"#2ca25f"},' ||
  '{"color":"#006d2c"}]'),
('dwedens', 'Dwelling density', 'dwellings per km²', '', 'float',
  '[{"max":5,"color":"#f2f0f7"},' ||
  '{"max":10,"color":"#dadaeb"},' ||
  '{"max":50,"color":"#bcbddc"},' ||
  '{"max":250,"color":"#9e9ac8"},' ||
  '{"max":1000,"color":"#756bb1"},' ||
  '{"color":"#810f7c"}]'),
('popdwe', 'People per dwelling', '', '', 'float',
  '[{"max":1,"color":"#edf8fb"},' ||
  '{"max":2,"color":"#b3cde3"},' ||
  '{"max":2.5,"color":"#8c96c6","label":"up to 2½"},' ||
  '{"max":3,"color":"#8856a7"},' ||
  '{"color":"#810f7c"}]'),
('pop2006', 'Population, 2006', '', '', 'integer', NULL),
('gro', 'Population growth', '%', 'How many more or fewer people are in this region', 'float',
  '[{"max":-5,"color":"#d7191c","label":"shrank over 5%"},' ||
  '{"max":0,"color":"#fdae61","label":"shrank"},' ||
  '{"max":4.9999,"color":"#ffffbf","label":"grew under 5%"},' ||
  '{"max":9.9999,"color":"#a6d96a","label":"grew under 10%"},' ||
  '{"color":"#1a9641","label":"grew at least 10%"}]'),
('agem', 'Population by age, male', '', '', 'string', NULL),
('agef', 'Population by age, female', '', '', 'string', NULL),
('age', 'Population by age', '', '', 'string', NULL),
('agemedian', 'Median age', '', '', 'float',
  '[{"max":34.999,"color":"#ffffb2","label":"median under 35"},' ||
  '{"max":39.999,"color":"#fecc5c","label":"under 40"},' ||
  '{"max":44.999,"color":"#fd8d3c","label":"under 45"},' ||
  '{"max":49.999,"color":"#f03b20","label":"under 50"},' ||
  '{"color":"#bd0026","label":"50 and over"}]'),
('sexm', 'Male percentage', '%', 'How many people are male', 'float',
  '[{"max":46.99999,"color":"#d7191c","label":"over 53% female"},' ||
  '{"max":48.99999,"color":"#fdae61","label":"over 51% female"},' ||
  '{"max":51,"color":"#ffffbf","label":"about even"},' ||
  '{"max":53,"color":"#abd9e9","label":"over 51% male"},' ||
  '{"color":"#2c7bb6","label":"over 53% male"}]'),
('bounds', 'SRID 4326 boundaries', '', '', 'string', NULL)
;

DROP TABLE IF EXISTS indicator_region_values;
CREATE TABLE indicator_region_values (
  region_id INT NOT NULL,
  indicator_id INT NOT NULL,
  value_integer INT,
  value_float FLOAT,
  value_string VARCHAR,
  note VARCHAR,
  PRIMARY KEY (region_id, indicator_id)
);
