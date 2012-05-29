#= require app
#= require state

state = window.OpenCensus.state

window.OpenCensus.controllers.zoom_controller = (map_view) ->
  old_region1 = state.region1
  old_region2 = state.region2

  region_to_bounds = (region) ->
    value = region.statistics?.bounds?.value
    return if !value?

    numbers = value.split(/,/g)
    xmin = numbers[0]
    ymin = numbers[1]
    xmax = numbers[2]
    ymax = numbers[3]

    new google.maps.LatLngBounds(
      new google.maps.LatLng(ymin, xmin),
      new google.maps.LatLng(ymax, xmax)
    )

  refresh = () ->
    if !state.region1? && !state.region2?
      if state.point1? && !old_region1? && !old_region2?
        map_view.map.setCenter(
          new google.maps.LatLng(
            state.point1.latlng.latitude,
            state.point1.latlng.longitude
          )
        )
        map_view.map.setZoom(15)
      return

    may_zoom = !old_region1? && !old_region2?

    old_region1 = state.region1
    old_region2 = state.region2

    bounds_list = []
    if !may_zoom
      bounds_list.push(map_view.map.getBounds())
    if state.region1?
      r1_bounds = region_to_bounds(state.region1)
      bounds_list.push(r1_bounds) if r1_bounds?
    if state.region2?
      r2_bounds = region_to_bounds(state.region2)
      bounds_list.push(r2_bounds) if r2_bounds?

    changed = may_zoom
    bounds = bounds_list[0]
    return if !bounds? # something's wrong with the data
    for other_bounds in bounds_list.slice(1)
      if !bounds.contains(other_bounds.getSouthWest()) || !bounds.contains(other_bounds.getNorthEast())
        bounds.union(other_bounds)
        changed = true

    map_view.map.fitBounds(bounds) if changed

  state.onRegion1Changed('zoom-controller', refresh)
  state.onRegion2Changed('zoom-controller', refresh)
  state.onPoint1Changed('zoom-controller', refresh)

  $(document).on 'opencensus:zoom_region.zoom_controller', (e, region) ->
    return if !region?
    bounds = region_to_bounds(region)
    return if !bounds?
    map_view.map.fitBounds(bounds)
