class CreateUniqueIndexOnIndicatorRegionValues < ActiveRecord::Migration
  def change
    add_index(:indicator_region_values, [ :indicator_id, :region_id, :year ], :unique => true, :name => :unique_index)
  end
end
