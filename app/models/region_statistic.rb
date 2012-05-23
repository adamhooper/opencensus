class RegionStatistic < ActiveRecord::Base
  establish_connection(:statistics)
  self.primary_key = :region_id

  def json
    @_json ||= if statistics[0] != ?{
      Zlib::Inflate.inflate(statistics)
    else
      statistics
    end
  end
end
