class Tile < ActiveRecord::Base
  establish_connection(:tiles)
  self.primary_keys = [ :zoom_level, :tile_row, :tile_column ]

  def json
    return @_json if @_json

    if tile_data[0] != ?{
      raw_json = Zlib::Inflate.inflate(tile_data)
    else
      raw_json = tile_data
    end

    regex = /"region_id":(\d+)/

    region_matches = raw_json.scan(regex)
    region_ids = region_matches.map(&:first).map(&:to_i)

    # In case a record is not found, let's remove it from consideration
    unused_region_ids = Set.new(region_ids)
    statistics = RegionStatistic.find_all_by_region_id(region_ids)

    replacements = Hash.new
    statistics.each do |rs|
      key = "\"region_id\":#{rs.id}"
      value = "\"statistics\":#{rs.json}"
      replacements[key] = value
      unused_region_ids.delete(rs.id)
    end

    unused_region_ids.each do |region_id|
      replacements["\"region_id\":#{region_id}"] = '"statistics":{}'
    end

    raw_json.gsub!(regex, replacements)

    @_json = raw_json
  end
end
