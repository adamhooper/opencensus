#= require app
#= require state
#= require views/map-view

state = window.OpenCensus.state
MapView = window.OpenCensus.views.MapView

# Calls state.setPoint()
map_controller = (map_view) ->
  google_latlng_to_point = (google_latlng) ->
    projection = map_view.map.getProjection()
    zoomLevel = map_view.map.getZoom()
    xy = projection.fromLatLngToPoint(google_latlng)
    world_xy = [ (xy.x - 128) / 256 * 20037508.342789244 * 2, -(xy.y - 128) / 256 * 20037508.342789244 * 2 ]
    latlng = { latitude: google_latlng.lat(), longitude: google_latlng.lng() }
    { world_xy: world_xy, latlng: latlng }

  map_view.onMapEvent 'click', (e) ->
    point = google_latlng_to_point(e.latLng)
    state.setPoint(point)

  map_view.onMarkerPositionChanged (latlng) ->
    point = google_latlng_to_point(latlng)
    state.setPoint(point)

  $(document).on 'opencensus:choose_latlng.map_controller', (e, latlng) ->
    point = google_latlng_to_point(latlng)
    state.setPoint(point)

  map_view.onMapEvent 'mousemove', (e) ->
    point = google_latlng_to_point(e.latLng)
    $(document).trigger('opencensus:mousemove', [point])

  map_view.onMapEvent 'mouseout', () ->
    $(document).trigger('opencensus:mouseout')

  map_view.onMapEvent 'bounds_changed', () ->
    map_bounds = map_view.map.getBounds()
    state.map_bounds = map_bounds

$ ->
  $div = $('#opencensus-wrapper div.map')
  map_view = new MapView($div[0])
  map_controller(map_view)
