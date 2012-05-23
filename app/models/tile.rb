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

    statistics = RegionStatistic.find(region_ids)

    replacements = Hash.new
    statistics.each do |rs|
      key = "\"region_id\":#{rs.id}"
      value = "\"statistics\":#{rs.json}"
      replacements[key] = value
    end

    raw_json.gsub!(regex, replacements)

    @_json = raw_json
  end
end
