CREATE TABLE regions (
  id SERIAL PRIMARY KEY,
  type VARCHAR NOT NULL,
  uid VARCHAR NOT NULL,
  name VARCHAR,
  given_area_in_m BIGINT,
  polygon_area_in_m BIGINT,
  position INT, -- so we render Provinces below DisseminationBlocks
  dissemination_block_uid VARCHAR,
  dissemination_area_uid VARCHAR,
  tract_uid VARCHAR,
  subdivision_uid VARCHAR,
  consolidated_subdivision_uid VARCHAR,
  division_uid VARCHAR,
  metropolitan_area_uid VARCHAR,
  province_uid VARCHAR,
  electoral_district_uid VARCHAR,
  economic_region_uid VARCHAR,
  statistical_area_uid VARCHAR,
  subtype VARCHAR,
  geometry GEOMETRY NOT NULL
);

CREATE INDEX regions_uid ON regions (uid);
CREATE INDEX regions_dissemination_block_uid ON regions (dissemination_block_uid);
CREATE INDEX regions_dissemination_area_uid ON regions (dissemination_area_uid);
CREATE INDEX regions_tract_uid ON regions (tract_uid);
CREATE INDEX regions_subdivision_uid ON regions (subdivision_uid);
CREATE INDEX regions_consolidated_subdivision_uid ON regions (consolidated_subdivision_uid);
CREATE INDEX regions_division_uid ON regions (division_uid);
CREATE INDEX regions_metropolitan_area_uid ON regions (metropolitan_area_uid);
CREATE INDEX regions_province_uid ON regions (province_uid);
CREATE INDEX regions_electoral_district_uid ON regions (electoral_district_uid);
CREATE INDEX regions_economic_region_uid_uid ON regions (tract_uid);
CREATE INDEX regions_statistical_area_uid ON regions (statistical_area_uid);
