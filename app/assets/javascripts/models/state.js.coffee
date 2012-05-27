#= require jquery

#= require app
#= require globals

globals = window.OpenCensus.globals
defaults = globals.defaults

# State variables:
# * indicator: the Indicator (object) we're dealing with. (For instance, the
#   'pop' indicator is set in State we're showing the 'popdens' number on the
#   map.)
# * point: A { world_xy: [x,y], latlng: { longitude, latitude }}
#   object that is the focus of everything
# * region_list: A list of all Regions underneath the point. If the point
#   remains constant this link will never lose items; however, it may gain
#   items if the user zooms in.
# * region1: A region--presumably one of the 11 possible regions at @point.
# * region2: A region we're comparing with @region1--again, presumably from
#   @region_list.
# * @hover_region: The region under the user's mouse pointer.
#
# Each of the above regions has a setter and a corresponding event: for
# instance, "onPointChanged()". (Use the property itself as a getter.)
#
# The following properties do not fire events, and they do not have setters.
#
# * @map_bounds: edges of the map (used as a geocoding hint)
class State
  constructor: ->
    @indicator = globals.indicators.findByKey(defaults.indicator_key)
    @region_list = undefined
    @region1 = undefined
    @region2 = undefined
    @hover_region = undefined
    @point = undefined
    @map_bounds = undefined

  setIndicator: (indicator) ->
    indicator = globals.indicators.findByKey(indicator) if typeof(indicator) == 'String'
    return if indicator?.key == @indicator?.key
    @indicator = indicator
    $(document).trigger('opencensus:state:indicator_changed', @indicator)

  setPoint: (point) ->
    return if point?.world_xy?[0] == @point?.world_xy?[0] &&
      point?.world_xy?[1] == @point?.world_xy?[1] &&
      point?.latlng?.latitude == @point?.latlng?.latitude &&
      point?.latlnt?.longitude == @point?.latlng?.longitude
    if point?
      @point = {
        world_xy: [ point.world_xy[0], point.world_xy[1] ],
        latlng: { latitude: point.latlng.latitude, longitude: point.latlng.longitude },
      }
    else
      @point = undefined
    $(document).trigger('opencensus:state:point_changed', @point)

  setRegionList: (region_list) ->
    return if !region_list? && !@region_list?
    equal = false
    if region_list? && @region_list? && region_list.length == @region_list.length
      equal = true
      for region, i in region_list
        if !region.equals(@region_list[i])
          equal = false
          break
    return if equal

    (globals.region_store.incrementCount(region.id) for region in region_list) if region_list?
    old_region_list = @region_list
    @region_list = region_list
    (globals.region_store.decrementCount(region.id) for region in old_region_list) if old_region_list?
    $(document).trigger('opencensus:state:region_list_changed', @region_list)

  _setRegionN: (n, region) ->
    key = "region#{n}"

    return if !region && !this[key]
    return if region && this[key] && region.equals(this[key])
    globals.region_store.decrementCount(this[key].id) if this[key]?
    this[key] = region
    globals.region_store.incrementCount(this[key].id) if this[key]?
    $(document).trigger("opencensus:state:region#{n}_changed", this[key])

  setRegion1: (region1) ->
    this._setRegionN(1, region1)

  setRegion2: (region2) ->
    this._setRegionN(2, region2)

  setHoverRegion: (hover_region) ->
    return if !hover_region && !@hover_region
    return if hover_region && @hover_region && hover_region.equals(@hover_region)
    globals.region_store.decrementCount(@hover_region.id) if @hover_region?
    @hover_region = hover_region
    globals.region_store.incrementCount(@hover_region.id) if @hover_region?
    $(document).trigger('opencensus:state:hover_region_changed', @hover_region)

  onIndicatorChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:indicator_changed.#{callerNamespace}", (e, indicator) ->
      func.call(oThis || window, indicator)

  onPointChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:point_changed.#{callerNamespace}", (e, point) ->
      func.call(oThis || window, point)

  onRegionListChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:region_list_changed.#{callerNamespace}", (e, region_list) ->
      func.call(oThis || window, region_list)

  onRegion1Changed: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:region1_changed.#{callerNamespace}", (e, region) ->
      func.call(oThis || window, region)

  onRegion2Changed: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:region2_changed.#{callerNamespace}", (e, region) ->
      func.call(oThis || window, region)

  onHoverRegionChanged: (callerNamespace, func, oThis = undefined) ->
    $(document).on "opencensus:state:hover_region_changed.#{callerNamespace}", (e, hover_region) ->
      func.call(oThis || window, hover_region)

  removeHandlers: (callerNamespace) ->
    $(document).off(".#{callerNamespace}")

window.OpenCensus.models.State = State
