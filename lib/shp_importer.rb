class ShpImporter
  attr_reader(:filename)
  attr_reader(:year)
  attr_reader(:options)

  def initialize(filename, year, options = {})
    @filename = filename.dup
    @year = year
    @options = options.dup
  end

  def import
    srs_database = RGeo::CoordSys::SRSDatabase::Proj4Data.new('epsg')
    factory = RGeo::Geos.factory(uses_lenient_multi_polygon_assertions: true, srs_database: srs_database, srid: Region::SHP_SRID)

    RGeo::Shapefile::Reader.open(filename, factory: factory, assume_inner_follows_outer: true) do |file|
      file.each do |record|
        region = Region.find_or_create_from_shp_record!(record)
        options[:logger].try(:info, "   #{region.type} #{region.uid} - #{region.name}...")
      end
    end
  end
end
