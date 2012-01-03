class AlterTableRegionTypesRenameTypeToName < ActiveRecord::Migration
  def change
    rename_column(:region_types, :type, :name)
  end
end
