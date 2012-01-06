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

ActiveRecord::Schema.define(:version => 20120106072212) do

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

  add_index "region_parents", ["parent_region_id", "region_id"], :name => "index_region_parents_on_parent_region_id_region_id"
  add_index "region_parents", ["parent_region_id"], :name => "index_region_parents_on_parent_region_id"
  add_index "region_parents", ["region_id", "parent_region_id"], :name => "index_region_parents_on_region_id_and_parent_region_id", :unique => true
  add_index "region_parents", ["region_id"], :name => "index_region_parents_on_region_id"

  create_table "region_parents_strings", :id => false, :force => true do |t|
    t.integer "region_id",                :null => false
    t.string  "parents",   :limit => nil
  end

  create_table "region_polygons", :id => false, :force => true do |t|
    t.integer "id",                                                                         :null => false
    t.integer "region_id",                                                                  :null => false
    t.spatial "polygon",        :limit => {:srid=>0, :type=>"geometry"},                    :null => false
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
    t.boolean "is_island",                                               :default => false, :null => false
  end

  add_index "region_polygons", ["max_longitude", "min_longitude", "max_latitude", "min_latitude", "area_in_m"], :name => "region_polygons_max_longitude_min_longitude_max_latitude_mi_idx"
  add_index "region_polygons", ["region_id", "id"], :name => "region_polygons_region_id_id_idx"
  add_index "region_polygons", ["region_id"], :name => "region_polygons_region_id_idx"

  create_table "region_polygons_zoom1", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom1", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom1_tile_matching_query"
  add_index "region_polygons_zoom1", ["region_id"], :name => "index_region_polygons_zoom1_on_region_id"

  create_table "region_polygons_zoom10", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom10", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom10_tile_matching_query"
  add_index "region_polygons_zoom10", ["region_id"], :name => "index_region_polygons_zoom10_on_region_id"

  create_table "region_polygons_zoom11", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom11", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom11_tile_matching_query"
  add_index "region_polygons_zoom11", ["region_id"], :name => "index_region_polygons_zoom11_on_region_id"

  create_table "region_polygons_zoom12", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom12", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom12_tile_matching_query"
  add_index "region_polygons_zoom12", ["region_id"], :name => "index_region_polygons_zoom12_on_region_id"

  create_table "region_polygons_zoom13", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom13", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom13_tile_matching_query"
  add_index "region_polygons_zoom13", ["region_id"], :name => "index_region_polygons_zoom13_on_region_id"

  create_table "region_polygons_zoom14", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom14", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom14_tile_matching_query"
  add_index "region_polygons_zoom14", ["region_id"], :name => "index_region_polygons_zoom14_on_region_id"

  create_table "region_polygons_zoom15", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom15", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom15_tile_matching_query"
  add_index "region_polygons_zoom15", ["region_id"], :name => "index_region_polygons_zoom15_on_region_id"

  create_table "region_polygons_zoom16", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom16", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom16_tile_matching_query"
  add_index "region_polygons_zoom16", ["region_id"], :name => "index_region_polygons_zoom16_on_region_id"

  create_table "region_polygons_zoom17", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom17", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom17_tile_matching_query"
  add_index "region_polygons_zoom17", ["region_id"], :name => "index_region_polygons_zoom17_on_region_id"

  create_table "region_polygons_zoom18", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom18", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom18_tile_matching_query"
  add_index "region_polygons_zoom18", ["region_id"], :name => "index_region_polygons_zoom18_on_region_id"

  create_table "region_polygons_zoom2", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom2", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom2_tile_matching_query"
  add_index "region_polygons_zoom2", ["region_id"], :name => "index_region_polygons_zoom2_on_region_id"

  create_table "region_polygons_zoom3", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom3", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom3_tile_matching_query"
  add_index "region_polygons_zoom3", ["region_id"], :name => "index_region_polygons_zoom3_on_region_id"

  create_table "region_polygons_zoom4", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom4", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom4_tile_matching_query"
  add_index "region_polygons_zoom4", ["region_id"], :name => "index_region_polygons_zoom4_on_region_id"

  create_table "region_polygons_zoom5", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom5", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom5_tile_matching_query"
  add_index "region_polygons_zoom5", ["region_id"], :name => "index_region_polygons_zoom5_on_region_id"

  create_table "region_polygons_zoom6", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom6", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom6_tile_matching_query"
  add_index "region_polygons_zoom6", ["region_id"], :name => "index_region_polygons_zoom6_on_region_id"

  create_table "region_polygons_zoom7", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom7", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom7_tile_matching_query"
  add_index "region_polygons_zoom7", ["region_id"], :name => "index_region_polygons_zoom7_on_region_id"

  create_table "region_polygons_zoom8", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom8", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom8_tile_matching_query"
  add_index "region_polygons_zoom8", ["region_id"], :name => "index_region_polygons_zoom8_on_region_id"

  create_table "region_polygons_zoom9", :id => false, :force => true do |t|
    t.integer "id",                                                     :null => false
    t.integer "region_id"
    t.float   "min_longitude"
    t.float   "max_longitude"
    t.float   "min_latitude"
    t.float   "max_latitude"
    t.integer "area_in_m",     :limit => 8
    t.boolean "is_island"
    t.spatial "polygon",       :limit => {:srid=>0, :type=>"geometry"}
  end

  add_index "region_polygons_zoom9", ["min_longitude", "max_longitude", "min_latitude", "max_latitude", "area_in_m", "is_island"], :name => "region_polygons_zoom9_tile_matching_query"
  add_index "region_polygons_zoom9", ["region_id"], :name => "index_region_polygons_zoom9_on_region_id"

  create_table "region_siblings", :id => false, :force => true do |t|
    t.integer "region_id",         :null => false
    t.integer "sibling_region_id", :null => false
  end

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
