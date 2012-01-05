class CreateRegionParents < ActiveRecord::Migration
  def change
    create_table(:region_parents) do |t|
      t.integer :region_id
      t.integer :parent_region_id
    end

    add_index(:region_parents, :region_id)
    add_index(:region_parents, :parent_region_id)
    add_index(:region_parents, [ :region_id, :parent_region_id ], :unique => true)
  end
end
