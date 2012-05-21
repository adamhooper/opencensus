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
  buckets VARCHAR, -- NULL when it isn't a mappable stat
  bucket_colors VARCHAR
);
INSERT INTO indicators (key, name, unit, description, value_type, buckets, bucket_colors)
VALUES
('pop', 'Population', '', '', 'integer', NULL, NULL),
('dwe', 'Dwellings', '', '', 'integer', NULL, NULL),
('occdwe', 'Occupied dwellings', '', '', 'integer', NULL, NULL),
('popdens', 'Population density', 'people per km²', '', 'float', 'less than 5, 5 to 20, 20 to 100, 100 to 500, 500 to 2000, more than 2000', '#edf8fb,#ccece6,#99d8c9,#66c2a4,#2ca25f,#006d2c'),
('dwedens', 'Dwelling density', 'dwellings per km²', '', 'float', 'less than 5, 5 to 10, 10 to 50, 50 to 250, 250 to 1000, more than 1000', '#f2f0f7,#dadaeb,#bcbddc,#9e9ac8,#756bb1,#54278f'),
('popdwe', 'People per dwelling', '', '', 'float', 'less than 1, 1 to 2, 2 to 2.5, 2.5 to 3, more than 3', '#edf8fb,#b3cde3,#8c96c6,#8856a7,#810f7c'),
('pop2006', 'Population, 2006', '', '', 'integer', NULL, NULL),
('gro', 'Population growth', '%', 'How many more or fewer people are in this region', 'float', 'less than -5, -5 to 0, 0 to 3, 3 to 10, more than 10', '#d7191c,#fdae61,#ffffbf,#a6d96a,#1a9641'),
('agem', 'Population by age, male', '', '', 'string', NULL, NULL),
('agef', 'Population by age, female', '', '', 'string', NULL, NULL),
('age', 'Population by age', '', '', 'string', NULL, NULL),
('agemean', 'Mean age', '', '', 'integer', 'less than 20, 20 to 30, 30 to 40, 40 to 50, more than 50', '#ffffd4,#fed98e,#fe9929,#d95f0e,#993404'),
('agemedian', 'Median age', '', '', 'integer', 'less than 20, 20 to 30, 30 to 40, 40 to 50, more than 50', '#ffffb2,#fecc5c,#fd8d3c,#f03b20,#bd0026');

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
