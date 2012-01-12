# Adds "is_island" column to polygons.
#
# If a polygon is an island, then it's visually important. In other words,
# most of the time a DistributionBlock 3 pixels squared isn't interesting,
# but when it's surrounded by water, it is.
#
# This migration doesn't *actually* try and figure out where the water is:
# it estimates. The heuristic:
#
# 1. Every polygon in a Province, ElectoralDistrict or MetropolitanArea is
#    an island.
# 2. Any other polygon that's identical to an island polygon is itself an
#    island.
#
# This column is designed for aesthetic and interactive pleasure, not for
# accuracy.
class AlterTableRegionPolygonsAddIsIsland < ActiveRecord::Migration
  def up
    add_column(:region_polygons, :is_island, :boolean, :default => false, :null => false)

    execute("UPDATE region_polygons SET is_island = TRUE WHERE region_id IN (SELECT id FROM regions WHERE type IN ('Province', 'ElectoralDistrict', 'MetropolitanArea'))")

    execute('UPDATE region_polygons SET is_island = TRUE WHERE is_island IS FALSE AND (max_longitude, min_longitude, max_latitude, min_latitude, area_in_m) IN (SELECT max_longitude, min_longitude, max_latitude, min_latitude, area_in_m FROM region_polygons WHERE is_island IS TRUE)')
  end

  def down
    remove_column(:region_polygons, :is_island)
  end
end
