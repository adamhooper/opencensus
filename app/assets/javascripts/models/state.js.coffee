#= require jquery

#= require app
#= require globals

globals = window.OpenCensus.globals
defaults = globals.defaults

class State
  constructor: ->
    @year = defaults.year
    @indicator = globals.indicators.findByName(defaults.indicator_name)
    @region = undefined
    @position = $.extend({}, defaults.position)

  setYear: (@year) ->
    $(document).trigger('opencensus:state:year-changed', @year)

  setIndicator: (@indicator) ->
    $(document).trigger('opencensus:state:indicator-changed', @indicator)

  setRegion: (@region) ->
    $(document).trigger('opencensus:state:region-changed', @region)

  setPosition: (position) ->
    @position = $.extend({}, position)
    $(document).trigger('opencensus:state:position-changed', @position)

  onYearChanged: (callerNamespace, func) ->
    $(document).on "opencensus:state:year-changed.#{callerNamespace}", (e, year) ->
      func(year)

  onIndicatorChanged: (callerNamespace, func) ->
    $(document).on "opencensus:state:indicator-changed.#{callerNamespace}", (e, indicator) ->
      func(indicator)

  onRegionChanged: (callerNamespace, func) ->
    $(document).on "opencensus:state:region-changed.#{callerNamespace}", (e, region) ->
      func(region)

  onPositionChanged: (callerNamespace, func) ->
    $(document).on "opencensus:state:position-changed.#{callerNamespace}", (e, position) ->
      func(position)

  removeHandlers: (callerNamespace) ->
    $(document).off(".#{callerNamespace}")

window.OpenCensus.models.State = State
