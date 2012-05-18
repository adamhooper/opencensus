#= require app

class Region
  constructor: (@id, @name, @parent_ids, @statistics) ->
    [@type, @uid] = @id.split(/-/)

  equals: (rhs) ->
    @type == rhs.type && @uid == rhs.uid

  getDatum: (year, indicator) ->
    return undefined unless @statistics?
    in_year = @statistics[year.toString()]
    return undefined unless in_year?
    in_year[indicator.name]

window.OpenCensus.models.Region = Region
