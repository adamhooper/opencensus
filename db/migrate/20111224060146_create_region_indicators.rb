class CreateRegionIndicators < ActiveRecord::Migration
  def change
    create_table(:region_indicators) do |t|
      t.integer(:region_id)
      t.string(:indicator_name)
      t.integer(:value_year)
      t.string(:value_type)
      t.integer(:value_integer)
      t.float(:value_float)
      t.string(:note)
    end

    add_index(:region_indicators, :region_id)
  end
end
