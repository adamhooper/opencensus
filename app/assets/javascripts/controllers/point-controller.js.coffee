#= require app
#= require state
#= require views/location-view

REGION = 'CA'

state = window.OpenCensus.state
LocationView = window.OpenCensus.views.LocationView

point_controller = (location_view) ->
  geocoder = new google.maps.Geocoder()
  freeze_listeners = false

  handle_geocoder_response = (results, status) ->
    if status == google.maps.GeocoderStatus.ZERO_RESULTS
      location_view.setStatus('error', 'Address not found')
    else if status == google.maps.GeocoderStatus.OK
      freeze_listeners = true
      location = results[0].geometry.location
      location_view.setStatus(undefined)
      $(document).trigger('opencensus:choose_latlng', location)
      freeze_listeners = false
    else
      location_view.setStatus('error', 'Address lookup failed')

  handle_reverse_geocoder_response = (results, status) ->
    location_view.setStatus(undefined)
    freeze_listeners = true
    if status == google.maps.GeocoderStatus.OK
      point_description = results[0].formatted_address
    else
      point_description = '(point on map)'
    location_view.setPointDescription(point_description)
    freeze_listeners = false

  maybe_lookup_address = (new_point_description) ->
    if $.trim(new_point_description || '').length > 0
      location_view.setStatus('notice', 'Looking up address')
      geocoder.geocode({
        address: new_point_description,
        region: REGION,
        bounds: state.map_bounds,
      }, (results, status) ->
        handle_geocoder_response(results, status)
      )

  maybe_lookup_point = (new_point) ->
    if !new_point?
      location_view.setStatus(undefined)
      location_view.setPointDescription('')
      return

    location_view.setStatus('notice', 'Looking up address')
    freeze_listeners = true
    location_view.setPointDescription('…')
    freeze_listeners = false
    geocoder.geocode({
      latLng: new google.maps.LatLng(new_point.latlng.latitude, new_point.latlng.longitude),
    }, (results, status) ->
      handle_reverse_geocoder_response(results, status)
    )

  set_point_description = (new_point_description) ->
    maybe_lookup_address(new_point_description)

  set_point = (new_point) ->
    maybe_lookup_point(new_point)

  location_view.onSubmit 'point_controller', () ->
    return if freeze_listeners
    new_point_description = location_view.getPointDescription()
    set_point_description(new_point_description)

  state.onPoint1Changed 'point_controller', () ->
    return if freeze_listeners
    set_point(state.point1)

$ ->
  $location_form = $('#opencensus-wrapper form.location')
  location_view = new LocationView($location_form[0])
  point_controller(location_view)
