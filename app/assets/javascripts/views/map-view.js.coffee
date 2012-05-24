#= require jquery

#= require state
#= require globals
#= require svg_map_type

state = window.OpenCensus.state
globals = window.OpenCensus.globals

class MapView
  constructor: (@div) ->
    latlng = new google.maps.LatLng(state.position.latitude, state.position.longitude)
    zoom = state.position.zoom

    mapTypeStyle = [
      {
        stylers: [
          { visibility: "off" }
        ]
      },{
        featureType: "water",
        elementType: "geometry",
        stylers: [
          { visibility: "on" },
          { saturation: -20 }
        ]
      },{
        featureType: "administrative.country",
        stylers: [
          { visibility: "on" }
        ]
      },{
        featureType: "administrative.province",
        stylers: [
          { visibility: "on" }
        ]
      },{
        featureType: "road.highway",
        stylers: [
          { visibility: "on" },
          { saturation: -100 },
          { gamma: 0.87 }
        ]
      },{
        featureType: "road.arterial",
        stylers: [
          { visibility: "on" },
          { saturation: -99 }
        ]
      }
    ]

    options = {
      zoom: zoom,
      minZoom: globals.min_zoom,
      maxZoom: globals.max_zoom,
      center: latlng,
      mapTypeId: google.maps.MapTypeId.ROADMAP,
      mapTypeControl: false,
      streetViewControl: false,
      styles: mapTypeStyle,
    }

    @map = new google.maps.Map(@div, options)

    svgMapType = new SvgMapType(new google.maps.Size(256, 256))
    @map.overlayMapTypes.insertAt(0, svgMapType)

    state.onPositionChanged('map', this.onPositionChanged, this)

    register_event = (event_type) =>
      google.maps.event.addListener @map, event_type, (e) =>
        projection = @map.getProjection()
        zoomLevel = @map.getZoom()
        xy = projection.fromLatLngToPoint(e.latLng)
        world_xy = [ (xy.x - 128) / 256 * 20037508.342789244 * 2, -(xy.y - 128) / 256 * 20037508.342789244 * 2 ]
        latlng = { latitude: e.latLng.lat(), longitude: e.latLng.lng() }
        $(document).trigger('opencensus:' + event_type, [{ world_xy: world_xy, latlng: latlng }])

    register_event(event_type) for event_type in [ 'mousemove', 'click' ]

    google.maps.event.addListener @map, 'mouseout', (e) ->
      $(document).trigger('opencensus:mouseout')

    google.maps.event.addListener(@map, 'bounds_changed', () => this.onMapBoundsChanged())

  onPositionChanged: (position) ->
    return if @handlingPositionChange
    @handlingPositionChange = true

    if position.bounds
      sw = new google.maps.LatLng(position.bounds[3], position.bounds[0])
      ne = new google.maps.LatLng(position.bounds[1], position.bounds[2])
      bounds = new google.maps.LatLngBounds(sw, ne)
      @map.fitBounds(bounds)
    else
      point = new google.maps.LatLng(position.latitude, position.longitude)
      zoom = position.zoom
      @map.setCenter(point)
      @map.setZoom(zoom)

    @handlingPositionChange = false

  onMapBoundsChanged: () ->
    return if @handlingPositionChange
    @handlingPositionChange = true

    latlng = @map.getCenter()
    bounds = @map.getBounds()
    position = {
      latitude: latlng.lat(),
      longitude: latlng.lng(),
      zoom: @map.getZoom(),
      bounds: [
        bounds.getSouthWest().lng(),
        bounds.getNorthEast().lat(),
        bounds.getNorthEast().lng(),
        bounds.getSouthWest().lat()
      ]
    }
    state.setPosition(position)

    @handlingPositionChange = false

$ ->
  $div = $('#opencensus-wrapper div.map')
  new MapView($div[0])
