class CreateRegions < ActiveRecord::Migration
  def change
    create_table :regions do |t|
      t.string :type
      t.string :uid
      t.string :name
      t.integer :year
      t.string :dissemination_block_uid
      t.string :dissemination_area_uid
      t.string :tract_uid
      t.string :subdivision_uid
      t.string :consolidated_subdivision_uid
      t.string :division_uid
      t.string :metropolitan_area_uid
      t.string :agglomeration_uid
      t.string :province_uid
      t.string :electoral_district_uid
      t.string :economic_region_uid
      t.string :statistical_area_uid
      t.geography(:geography, :geographic => true)

      t.timestamps
    end

  add_index(:regions, :uid)
  end
end
