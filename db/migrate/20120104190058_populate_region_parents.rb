class PopulateRegionParents < ActiveRecord::Migration
  def up
    rels = {
      'DisseminationBlock' => [ 'dissemination_area', 'electoral_district' ],
      'DisseminationArea' => [ 'tract', 'subdivision' ],
      'Tract' => [ 'metropolitan_area' ],
      'Subdivision' => [ 'consolidated_subdivision', 'metropolitan_area' ],
      'ConsolidatedSubdivision' => [ 'division' ],
      'Division' => [ 'economic_region' ],
      'EconomicRegion' => [ 'province' ],
      'ElectoralDistrict' => [ 'province' ]
      # province and metropolitan_area have no parents
    }

    rels.each do |child_type, parent_columns|
      parent_columns.each do |parent_column|
        parent_type = parent_column.camelize
        execute("INSERT INTO region_parents (region_id, parent_region_id) SELECT r.id, p.id FROM regions r INNER JOIN regions p ON p.uid = r.#{parent_column}_uid AND p.type = '#{parent_type}' WHERE r.type = '#{child_type}'")
      end
    end
  end

  def down
    execute('DELETE FROM region_parents')
  end
end
