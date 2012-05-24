#= require app

class Region
  constructor: (@id, @name, @parent_ids, @statistics) ->
    [@type, @uid] = @id.split(/-/)

  equals: (rhs) ->
    @type == rhs.type && @uid == rhs.uid

  getDatum: (indicator) ->
    indicator_key = typeof(indicator) == 'String' && indicator || indicator.key
    @statistics?[indicator_key]

window.OpenCensus.models.Region = Region
