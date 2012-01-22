# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20120111154341) do

  create_table "indicator_region_types", :id => false, :force => true do |t|
    t.integer "id",             :null => false
    t.integer "indicator_id"
    t.integer "region_type_id"
  end

  create_table "indicator_region_values", :force => true do |t|
    t.integer "indicator_id"
    t.integer "region_id"
    t.integer "year"
    t.integer "value_integer"
    t.float   "value_float"
    t.string  "note"
  end

  add_index "indicator_region_values", ["indicator_id", "region_id", "year"], :name => "indicator_region_values_unique_index", :unique => true
  add_index "indicator_region_values", ["indicator_id", "region_id"], :name => "indicator_region_values_indicator_id_region_id"
  add_index "indicator_region_values", ["indicator_id"], :name => "indicator_region_values_indicator_id"
  add_index "indicator_region_values", ["region_id", "indicator_id"], :name => "indicator_region_values_region_id_indicator_id"
  add_index "indicator_region_values", ["region_id"], :name => "indicator_region_values_region_id"

  create_table "indicators", :force => true do |t|
    t.string "name"
    t.string "unit"
    t.string "description"
    t.string "value_type"
    t.string "buckets"
    t.string "sql"
  end

  create_table "region_indicators", :id => false, :force => true do |t|
    t.integer "id",             :null => false
    t.integer "region_id"
    t.string  "indicator_name"
    t.integer "value_year"
    t.string  "value_type"
    t.integer "value_integer"
    t.float   "value_float"
    t.string  "note"
  end

  create_table "region_parents", :force => true do |t|
    t.integer "region_id"
    t.integer "parent_region_id"
  end

  add_index "region_parents", ["parent_region_id", "region_id"], :name => "index_region_parents_on_parent_region_id_region_id"
  add_index "region_parents", ["parent_region_id"], :name => "index_region_parents_on_parent_region_id"
  add_index "region_parents", ["region_id", "parent_region_id"], :name => "index_region_parents_on_region_id_and_parent_region_id", :unique => true
  add_index "region_parents", ["region_id"], :name => "index_region_parents_on_region_id"

  create_table "region_parents_strings", :id => false, :force => true do |t|
    t.integer "region_id",                :null => false
    t.string  "parents",   :limit => nil
  end

# Could not dump table "region_polygons" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom0" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom1" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom10" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom11" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom12" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom13" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom14" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom15" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom16" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom17" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom18" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom2" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom3" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom4" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom5" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom6" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom7" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom8" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

# Could not dump table "region_polygons_zoom9" because of following StandardError
#   Unknown type 'geometry' for column 'polygon'

  create_table "region_type_parents", :force => true do |t|
    t.string "region_type"
    t.string "parent_region_type"
  end

  create_table "region_types", :id => false, :force => true do |t|
    t.integer "id",                      :null => false
    t.string  "name",     :limit => nil, :null => false
    t.integer "position",                :null => false
  end

  add_index "region_types", ["name"], :name => "region_types_type_idx"

# Could not dump table "regions" because of following StandardError
#   Unknown type 'geometry' for column 'geometry'

  create_table "spatial_ref_sys", :id => false, :force => true do |t|
    t.integer "srid",                      :null => false
    t.string  "auth_name", :limit => 256
    t.integer "auth_srid"
    t.string  "srtext",    :limit => 2048
    t.string  "proj4text", :limit => 2048
  end

end
