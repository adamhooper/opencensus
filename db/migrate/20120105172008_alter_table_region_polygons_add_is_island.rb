# Adds "is_island" column to polygons.
#
# If a polygon is an island, then it's visually important. In other words,
# most of the time a DistributionBlock 3 pixels squared isn't interesting,
# but when it's surrounded by water, it is.
#
# This migration doesn't *actually* try and figure out where the water is:
# it estimates. The heuristic:
#
# "If two polygons are identical, then they represent an island."
# 
# Here's why. The two polygons represent the exact same area. The fact that
# there are more than one of them means they're from different region types
# (for instance, one is from a DistributionBlock and the other is a
# DistributionArea). Since they're in the same place, we can assume one is
# a parent of the other. And since the parent's polygon is no larger than its
# child's polygon, it must be isolated. Hence, it's an island.
#
# Even if this heuristic isn't perfect, that's fine. This column is designed
# for aesthetic and interactive pleasure, not for accuracy.
class AlterTableRegionPolygonsAddIsIsland < ActiveRecord::Migration
  def up
    add_column(:region_polygons, :is_island, :boolean, :default => false, :null => false)

    execute('UPDATE region_polygons SET is_island = TRUE WHERE id IN (SELECT UNNEST(arr) FROM (SELECT ARRAY_AGG(id) AS arr FROM region_polygons GROUP BY max_longitude, min_longitude, max_latitude, min_latitude, area_in_m HAVING COUNT(*) > 1) x)')
  end

  def down
    remove_column(:region_polygons, :is_island)
  end
end
