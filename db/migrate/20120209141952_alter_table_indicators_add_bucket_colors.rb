class AlterTableIndicatorsAddBucketColors < ActiveRecord::Migration
  def change
    add_column(:indicators, :bucket_colors, :string)
  end
end
