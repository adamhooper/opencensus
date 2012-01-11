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
    @hover_region = undefined
    @position = $.extend({}, defaults.position)

    $(document).on('opencensus:regionclick.state', (e, region) => this.setRegion(region))
    $(document).on('opencensus:regionhover.state', (e, region) => this.setHoverRegion(region))

  setYear: (year) ->
    return if year == @year
    @year = year
    $(document).trigger('opencensus:state:year_changed', @year)

  setIndicator: (indicator) ->
    return if indicator.equals(@indicator)
    @indicator = indicator
    $(document).trigger('opencensus:state:indicator_changed', @indicator)

  setRegion: (region) ->
    return if !region && !@region
    return if region && @region && region.equals(@region)
    @region = region
    $(document).trigger('opencensus:state:region_changed', @region)

  setHoverRegion: (hover_region) ->
    return if !hover_region && !@hover_region
    return if hover_region && @hover_region && hover_region.equals(@hover_region)
    @hover_region = hover_region
    $(document).trigger('opencensus:state:hover_region_changed', @hover_region)

  setPosition: (position) ->
    return if position.latitude = @position.latitude && position.longitude == @position.longitude && position.zoom == @position.zoom
    @position = $.extend({}, position)
    $(document).trigger('opencensus:state:position_changed', @position)

  onYearChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:year_changed.#{callerNamespace}", (e, year) ->
      func.call(oThis || window, year)

  onIndicatorChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:indicator_changed.#{callerNamespace}", (e, indicator) ->
      func.call(oThis || window, indicator)

  onRegionChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:region_changed.#{callerNamespace}", (e, region) ->
      func.call(oThis || window, region)

  onHoverRegionChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:hover_region_changed.#{callerNamespace}", (e, hover_region) ->
      func.call(oThis || window, hover_region)

  onPositionChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:position_changed.#{callerNamespace}", (e, position) ->
      func.call(oThis || window, position)

  removeHandlers: (callerNamespace) ->
    $(document).off(".#{callerNamespace}")

window.OpenCensus.models.State = State
