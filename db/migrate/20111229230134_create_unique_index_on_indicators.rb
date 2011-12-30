class CreateUniqueIndexOnIndicators < ActiveRecord::Migration
  def change
    add_index(:indicators, :name, :unique => true)
  end
end
