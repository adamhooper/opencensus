class AlterTableRegionsAddSubtype < ActiveRecord::Migration
  def change
    change_table(:regions) do |t|
      t.string :subtype
    end
  end
end
