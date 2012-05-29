#= require app
#= require models/region-type

$ = jQuery

RegionType = window.OpenCensus.models.RegionType

class RegionTypeDb
  constructor: (properties_list) ->
    @region_types = (new RegionType(properties) for properties in properties_list)
    @region_types_by_name = {}
    (@region_types_by_name[region_type.name] = region_type) for region_type in @region_types

  findByName: (name) ->
    @region_types_by_name[name]

  indexOfName: (name) ->
    for region_type, i in @region_types
      return i if region_type.name == name
    return undefined

window.OpenCensus.models.RegionTypeDb = RegionTypeDb
