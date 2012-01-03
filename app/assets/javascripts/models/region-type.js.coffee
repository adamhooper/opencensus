#= require app

class RegionType
  constructor: (properties) ->
    @name = properties.name
    @description = properties.description

window.OpenCensus.models.RegionType = RegionType
