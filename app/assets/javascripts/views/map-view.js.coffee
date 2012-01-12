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
        elementType: "geometry",
        stylers: [
          { saturation: -100 },
          { gamma: 0.5 }
        ]
      },{
        elementType: "labels",
        stylers: [
          { visibility: "off" }
        ]
      },{
        featureType: "water",
        stylers: [
          { saturation: 35 },
          { lightness: 14 }
        ]
      }
    ]

    options = {
      zoom: zoom,
      minZoom: globals.min_zoom,
      maxZoom: globals.max_zoom,
      center: latlng,
      mapTypeId: google.maps.MapTypeId.ROADMAP,
      styles: mapTypeStyle
    }

    @map = new google.maps.Map(@div, options)
    @inHandlers = {}

    register_event = (event_type) =>
      google.maps.event.addListener @map, event_type, (e) =>
        projection = @map.getProjection()
        zoomLevel = @map.getZoom()
        latLng = e.latLng
        world_xy = projection.fromLatLngToPoint(latLng)
        multiplier = 1 << zoomLevel
        pixel_xy = [
          Math.round(world_xy.x * multiplier),
          Math.round(world_xy.y * multiplier)
        ]
        $(document).trigger('opencensus:' + event_type, [pixel_xy])

    register_event(event_type) for event_type in [ 'mousemove', 'click' ]

    google.maps.event.addListener @map, 'mouseout', (e) ->
      $(document).trigger('opencensus:mouseout')

    google.maps.event.addListener(@map, 'bounds_changed', () => this.onMapBoundsChanged())

    svgMapType = new SvgMapType(new google.maps.Size(256, 256))
    @map.overlayMapTypes.insertAt(0, svgMapType)

    state.onPositionChanged('map', this.onPositionChanged, this)

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
  div = document.getElementById('map')
  new MapView(div)
