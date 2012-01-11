class CreateTableRegionTypeParents < ActiveRecord::Migration
  def change
    create_table(:region_type_parents) do |t|
      t.string(:region_type)
      t.string(:parent_region_type)
    end
  end
end
