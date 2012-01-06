class CreateTablesRegionPolygonsZoom < ActiveRecord::Migration
  def up
    (1..18).each do |zoom|
      table = "region_polygons_zoom#{zoom}"
      execute("SELECT id, region_id, min_longitude, max_longitude, min_latitude, max_latitude, area_in_m, is_island, polygon_zoom#{zoom} AS polygon INTO #{table} FROM region_polygons")
      execute("ALTER TABLE #{table} ADD PRIMARY KEY (id)")
      add_index(table, [ :region_id ])
      add_index(table, [ :min_longitude, :max_longitude, :min_latitude, :max_latitude, :area_in_m, :is_island ], :name => "#{table}_tile_matching_query")
    end
  end

  def down
    (1..18).each do |zoom|
      drop_table("region_polygons_zoom#{zoom}")
    end
  end
end
