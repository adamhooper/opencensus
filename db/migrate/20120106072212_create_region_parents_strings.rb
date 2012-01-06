class CreateRegionParentsStrings < ActiveRecord::Migration
  def up
    execute("""
        SELECT region_parents.region_id, STRING_AGG(CONCAT(regions.type, '-', regions.uid), ',')::varchar AS parents
        INTO region_parents_strings
        FROM region_parents
        INNER JOIN regions ON region_parents.parent_region_id = regions.id
        GROUP BY region_parents.region_id
        """)
    execute('ALTER TABLE region_parents_strings ADD PRIMARY KEY (region_id)')
  end

  def down
    execute('DROP TABLE region_parents_strings')
  end
end
