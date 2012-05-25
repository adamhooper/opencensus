#= require app
#= require globals

region_types = window.OpenCensus.globals.region_types

class Region
  constructor: (@id, @name, @parent_ids, @statistics) ->
    [@type, @uid] = @id.split(/-/)

  equals: (rhs) ->
    @id == rhs.id

  compareTo: (rhs) ->
    return 1 if !rhs?
    v1 = this.statistics?.pop?.value || -region_types.indexOfName(@type)
    v2 = rhs?.statistics?.pop?.value || -region_types.indexOfName(rhs.type)
    v1 - v2

  getDatum: (indicator) ->
    indicator_key = typeof(indicator) == 'String' && indicator || indicator.key
    @statistics?[indicator_key]

  human_name: () ->
    @id

window.OpenCensus.models.Region = Region
