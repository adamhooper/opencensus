#= require app

class Region
  constructor: (@id, @name, @parent_ids, @statistics) ->
    [@type, @uid] = @id.split(/-/)

  equals: (rhs) ->
    @type == rhs.type && @uid == rhs.uid

  getDatum: (indicator) ->
    @statistics?[indicator.name]

window.OpenCensus.models.Region = Region
