#= require app

class Region
  constructor: (@type, @uid, @name, @parent_ids, @statistics) ->

  id: () ->
    "#{@type}-#{@uid}"

  equals: (rhs) ->
    @type == rhs.type && @uid == rhs.uid

  getDatum: (year, indicator) ->
    return undefined unless @statistics
    in_year = @statistics[year.toString()]
    return undefined unless in_year
    in_year[indicator.name]

window.OpenCensus.models.Region = Region
