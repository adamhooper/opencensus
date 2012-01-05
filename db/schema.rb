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

ActiveRecord::Schema.define(:version => 20120104193042) do

  create_table "gccs000b06a_e", :id => false, :force => true do |t|
    t.integer "gid",                                                                         :null => false
    t.string  "CCSUID",  :limit => 7
    t.string  "CCSNAME", :limit => 100
    t.string  "PRUID",   :limit => 2
    t.string  "PRNAME",  :limit => 100
    t.spatial "geog",    :limit => {:srid=>4326, :type=>"multi_polygon", :geographic=>true}
  end

  create_table "gcd_000b06a_e", :id => false, :force => true do |t|
    t.integer "gid",                                                                        :null => false
    t.string  "CDUID",  :limit => 4
    t.string  "CDNAME", :limit => 100
    t.string  "CDTYPE", :limit => 3
    t.string  "PRUID",  :limit => 2
    t.string  "PRNAME", :limit => 100
    t.spatial "geog",   :limit => {:srid=>4326, :type=>"multi_polygon", :geographic=>true}
  end

  create_table "gcma000b06a_e", :id => false, :force => true do |t|
    t.integer "gid",                                                                         :null => false
    t.string  "CMAUID",  :limit => 5
    t.string  "CMANAME", :limit => 100
    t.string  "CMATYPE", :limit => 1
    t.string  "PRUID",   :limit => 2
    t.string  "PRNAME",  :limit => 100
    t.spatial "geog",    :limit => {:srid=>4326, :type=>"multi_polygon", :geographic=>true}
  end

  create_table "gcsd000b06a_e", :id => false, :force => true do |t|
    t.integer "gid",                                                                         :null => false
    t.string  "CSDUID",  :limit => 7
    t.string  "CSDNAME", :limit => 100
    t.string  "CSDTYPE", :limit => 3
    t.string  "PRUID",   :limit => 2
    t.string  "PRNAME",  :limit => 100
    t.string  "CDUID",   :limit => 4
    t.string  "CDNAME",  :limit => 100
    t.string  "CDTYPE",  :limit => 3
    t.string  "CMAUID",  :limit => 3
    t.string  "CMANAME", :limit => 100
    t.string  "SACTYPE", :limit => 1
    t.string  "ERUID",   :limit => 4
    t.string  "ERNAME",  :limit => 100
    t.spatial "geog",    :limit => {:srid=>4326, :type=>"multi_polygon", :geographic=>true}
  end

  create_table "ger_000b06a_e", :id => false, :force => true do |t|
    t.integer "gid",                                                                        :null => false
    t.string  "ERUID",  :limit => 4
    t.string  "ERNAME", :limit => 100
    t.string  "PRUID",  :limit => 2
    t.string  "PRNAME", :limit => 100
    t.spatial "geog",   :limit => {:srid=>4326, :type=>"multi_polygon", :geographic=>true}
  end

  create_table "gpr_000b06a_e", :id => false, :force => true do |t|
    t.integer "gid",                                                                         :null => false
    t.string  "PRUID",   :limit => 2
    t.string  "PRNAME",  :limit => 100
    t.string  "PRENAME", :limit => 100
    t.string  "PRFNAME", :limit => 100
    t.string  "PREABBR", :limit => 10
    t.string  "PRFABBR", :limit => 10
    t.spatial "geog",    :limit => {:srid=>4326, :type=>"multi_polygon", :geographic=>true}
  end

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

  add_index "region_parents", ["parent_region_id"], :name => "index_region_parents_on_parent_region_id"
  add_index "region_parents", ["region_id", "parent_region_id"], :name => "index_region_parents_on_region_id_and_parent_region_id", :unique => true
  add_index "region_parents", ["region_id"], :name => "index_region_parents_on_region_id"

  create_table "region_polygon_siblings", :force => true do |t|
    t.integer "region_polygon_id"
    t.integer "sibling_region_polygon_id"
    t.float   "distance_in_m"
  end

  create_table "region_polygons", :id => false, :force => true do |t|
    t.integer "id",                                                      :null => false
    t.integer "region_id",                                               :null => false
    t.spatial "polygon",        :limit => {:srid=>0, :type=>"geometry"}, :null => false
    t.integer "area_in_m",      :limit => 8
    t.spatial "polygon_zoom1",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom2",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom3",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom4",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom5",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom6",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom7",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom8",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom9",  :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom10", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom11", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom12", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom13", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom14", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom15", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom16", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom17", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "polygon_zoom18", :limit => {:srid=>0, :type=>"geometry"}
    t.spatial "bounding_box",   :limit => {:srid=>0, :type=>"geometry"}
    t.float   "min_latitude"
    t.float   "min_longitude"
    t.float   "max_latitude"
    t.float   "max_longitude"
  end

  add_index "region_polygons", ["max_longitude", "min_longitude", "max_latitude", "min_latitude", "area_in_m"], :name => "region_polygons_max_longitude_min_longitude_max_latitude_mi_idx"

  create_table "region_types", :id => false, :force => true do |t|
    t.integer "id",                      :null => false
    t.string  "name",     :limit => nil, :null => false
    t.integer "position",                :null => false
  end

  add_index "region_types", ["name"], :name => "region_types_type_idx"

  create_table "regions", :force => true do |t|
    t.string   "type"
    t.string   "uid"
    t.string   "name"
    t.integer  "year"
    t.string   "dissemination_block_uid"
    t.string   "dissemination_area_uid"
    t.string   "tract_uid"
    t.string   "subdivision_uid"
    t.string   "consolidated_subdivision_uid"
    t.string   "division_uid"
    t.string   "metropolitan_area_uid"
    t.string   "agglomeration_uid"
    t.string   "province_uid"
    t.string   "electoral_district_uid"
    t.string   "economic_region_uid"
    t.string   "statistical_area_uid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.spatial  "geometry",                     :limit => {:srid=>0, :type=>"geometry"}
    t.integer  "area_in_m",                    :limit => 8
    t.integer  "position"
    t.string   "subtype"
  end

  add_index "regions", ["area_in_m"], :name => "regions_area_in_m_idx"
  add_index "regions", ["geometry"], :name => "geometry", :spatial => true
  add_index "regions", ["type"], :name => "regions_type_idx"
  add_index "regions", ["type"], :name => "regions_type_idx1"
  add_index "regions", ["uid"], :name => "index_regions_on_uid"

end
