#= require app
#= require models/region-type

RegionType = window.OpenCensus.models.RegionType

class RegionTypeDb
  constructor: (properties_list) ->
    @region_types = (new RegionType(properties) for properties in properties_list)
    @region_types_by_name = {}
    (@region_types_by_name[name] = region_type) for region_type in @region_types

  findByName: (name) ->
    @region_types_by_name[name]

window.OpenCensus.models.RegionTypeDb = RegionTypeDb
