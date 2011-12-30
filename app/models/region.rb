class Region < ActiveRecord::Base
  has_many(:indicator_region_values)

  self.rgeo_factory_generator = RGeo::Geos.factory_generator

  SHP_SRID = 6269 # NAD83, which is what Statistics Canada uses (see .prj files...)
  JSON_SRID = 4326 # WGS84, which is the GeoJSON standard

  DBF_COLUMN_TYPES = %W(DB DA CT CSD CCS CD FED CMA ER PR)
  DBF_COLUMN_TO_TYPE = {
    'DB' => 'DisseminationBlock',
    'DA' => 'DisseminationArea',
    'CT' => 'Tract',
    'CSD' => 'Subdivision',
    'CCS' => 'ConsolidatedSubdivision',
    'CD' => 'Division',
    'FED' => 'ElectoralDistrict',
    'CMA' => 'MetropolitanArea',
    'ER' => 'EconomicRegion',
    'PR' => 'Province'
  }
  class_attribute(:shp_column_type)
  class_attribute(:parent_region_type_names)

  def shp_record=(shp_record)
    self.uid = shp_record.attributes[self.class.shp_uid_attribute]
    shp_name = shp_record.attributes[self.class.shp_name_attribute] || ''
    self.name = shp_name.force_encoding('ISO-8859-1').encode('UTF-8')

    DBF_COLUMN_TO_TYPE.each do |key, val|
      uid_key = "#{key}UID"
      if shp_record.attributes.has_key?(uid_key)
        column = "#{val.underscore}_uid"
        uid = shp_record.attributes[uid_key]
        self[column] = uid
      end
    end

    self.geometry_binary = shp_record.geometry.as_binary
  end

  def populate_geometry_wgs84_json(options = {})
    srs_database = RGeo::CoordSys::SRSDatabase::Proj4Data.new('epsg')

    feature_factory = RGeo::Gegraphic.projected_factory(
      uses_lenient_multi_polygon_assertions: true,
      srs_database: srs_database,
      srid: Region::SHP_SRID,
      projection_srid: JSON_SRID
    )

    geometry = feature_factory.parse_wkb(geometry_binary)
    json_geometry = feature_factory.project(geometry)

    json_factory = RGeo::GeoJSON::EntityFactory.instance()
    json_feature = json_factory.feature(json_geometry, uid, properties)

    hash = RGeo::GeoJSON.encode(json_feature)
    json = hash.to_json

    self.geometry_wgs84_json = json
  end

  def ancestors
    uids = ancestor_region_type_names.collect { |type| send("#{type.underscore}_uid") }
    Region.where(:uid => uids).all
  end

  def properties
    { name: name }
  end

  def self.find_or_create_from_shp_record!(shp_record)
    DBF_COLUMN_TYPES.each do |dbf_column|
      uid_column = "#{dbf_column}UID"
      if shp_record.attributes.has_key?(uid_column)
        uid = shp_record.attributes[uid_column]
        type_name = DBF_COLUMN_TO_TYPE[dbf_column]
        region = type_name.constantize.find_or_initialize_by_uid(uid)
        if region.new_record?
          region.shp_record = shp_record
          region.save!
        end
        return region
      end
    end

    raise "Unknown region type for record #{shp_record.attributes.inspect}"
  end

  def self.ancestor_region_types
    ancestor_region_type_names.map(&:constantize)
  end

  def self.ancestor_region_type_names
    next_level = []
    lower_level = parent_region_type_names.map
    while next_level.length < lower_level.length
      next_level = lower_level
      lower_level = next_level.map{ |s| s.constantize.parent_region_type_names }.flatten.uniq
    end
    next_level
  end

  def self.shp_uid_attribute
    "#{shp_column_type}UID"
  end

  def self.shp_name_attribute
    "#{shp_column_type}NAME"
  end
end
