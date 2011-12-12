class JsonExporter
  SRID = 6269 # NAD83, which is what Statistics Canada uses (see .prj files...)

  attr_reader(:filename)
  attr_reader(:options)

  def initialize(filename, options = {})
    @filename = filename.dup
    @options = options.dup
  end

  def export(regions)
    srs_database = RGeo::CoordSys::SRSDatabase::Proj4Data.new('epsg')
    feature_factory = RGeo::Geos.factory(uses_lenient_multi_polygon_assertions: true, srs_database: srs_database, srid: Region::SHP_SRID)

    json_factory = RGeo::GeoJSON::EntityFactory.instance()

    features = regions.map do |region|
      id = region.uid
      properties = region.properties
      geometry = feature_factory.parse_wkb(region.geometry_binary)

      json_factory.feature(geometry, id, properties)
    end
    feature_collection = json_factory.feature_collection(features)

    hash = RGeo::GeoJSON.encode(feature_collection)

    File.open(filename, 'w') do |file|
      file.write(hash.to_json)
    end
  end
end
