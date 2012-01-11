#= require app

class Region
  constructor: (@type, @uid, @name, @statistics) ->

  id: () ->
    "#{@type}-#{@uid}"

  equals: (rhs) ->
    @type == rhs.type && @uid == rhs.uid

window.OpenCensus.models.Region = Region
