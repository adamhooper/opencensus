class Region < ActiveRecord::Base
  has_many(:indicator_region_values)

  SRID = 4326 # WGS84, which is the GeoJSON standard

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
  class_attribute(:parent_region_type_names)

  def ancestors
    uids = ancestor_region_type_names.collect { |type| send("#{type.underscore}_uid") }
    Region.where(:uid => uids).all
  end

  def self.parent_region_types
    parent_region_type_names.map(&:constantize)
  end

  def self.ancestor_region_types
    ret = []
    lower_level = parent_region_types
    while lower_level.length > 0
      ret.concat(lower_level)
      lower_level = ret.map(&:parent_region_type_names).flatten.uniq.map(&:constantize).reject{ |k| ret.include?(k) }
    end
    ret
  end

  def self.ancestor_region_type_names
    ancestor_region_types.map(&:name)
  end
end
