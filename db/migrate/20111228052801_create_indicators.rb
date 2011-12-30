class CreateIndicators < ActiveRecord::Migration
  def change
    create_table(:indicators) do |t|
      t.string :name
      t.string :unit
      t.string :description
      t.string :value_type
      t.string :buckets
      t.string :sql
    end

    create_table(:indicator_region_types) do |t|
      t.integer :indicator_id
      t.integer :region_type_id
    end
  end
end
