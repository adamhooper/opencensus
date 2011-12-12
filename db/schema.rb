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

ActiveRecord::Schema.define(:version => 20111201020503) do

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
    t.spatial  "geography",                    :limit => {:srid=>4326, :type=>"geometry", :geographic=>true}
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "regions", ["uid"], :name => "index_regions_on_uid"

end
