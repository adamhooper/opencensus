#= require app
#= require state

$ = jQuery

state = window.OpenCensus.state

window.OpenCensus.controllers.zoom_controller = (map_view) ->
  # We zoom in when somebody types in an address
  zoom = (latlng) ->
    if state.point2?
      bounds = map_view.map.getBounds()
      if !bounds.contains(latlng)
        bounds.extend(latlng)
        map_view.map.fitBounds(bounds)
    else
      map_view.map.setCenter(latlng)
      map_view.map.setZoom(15)

  $(document).on 'opencensus:choose_latlng.zoom_controller', (e, latlng) ->
    zoom(latlng)
