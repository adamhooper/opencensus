class CreateIndicatorRegionValues < ActiveRecord::Migration
  def change
    create_table(:indicator_region_values) do |t|
      t.integer :indicator_id
      t.integer :region_id
      t.integer :year
      t.integer :value_integer
      t.float :value_float
      t.string :note
    end

    add_index(:indicator_region_values, :indicator_id)
    add_index(:indicator_region_values, :region_id)
    add_index(:indicator_region_values, [:indicator_id, :region_id])
    add_index(:indicator_region_values, [:region_id, :indicator_id])
  end
end
