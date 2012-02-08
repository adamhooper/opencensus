class CreateTablesRegionPolygonsZoom < ActiveRecord::Migration
  def up
    zoom0_degrees_per_pixel = (170.0 / 256)

    (0..15).each do |zoom|
      # We can be off by 1 pixel with nobody noticing, because shapes have borders.
      # So let's convert that to degrees--that's our allowed_error
      degrees_per_pixel = zoom0_degrees_per_pixel / (2 ** zoom)
      allowed_error = 2 * degrees_per_pixel # fuzzy -- lon has more degrees per pixel than lat

      table = "region_polygons_zoom#{zoom}"
      execute("SELECT id, region_id, min_longitude, max_longitude, min_latitude, max_latitude, area_in_m, is_island, ST_MakeValid(ST_Buffer(ST_SimplifyPreserveTopology(polygon, #{allowed_error}), 0)) AS polygon INTO #{table} FROM region_polygons")
      execute("ALTER TABLE #{table} ADD PRIMARY KEY (id)")
      add_index(table, [ :region_id ])
      add_index(table, [ :min_longitude, :max_longitude, :min_latitude, :max_latitude, :area_in_m, :is_island ], :name => "#{table}_tile_matching_query")
    end
  end

  def down
    (0..18).each do |zoom|
      table_name = "region_polygons_zoom#{zoom}"
      drop_table(table_name) if self.table_exists?(table_name)
    end
  end
end
