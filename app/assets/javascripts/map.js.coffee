#= require jquery
#= require svg_map_type

$ ->
  latlng = new google.maps.LatLng(45.5, -73.5)
  zoom = 9

  map_tag = document.getElementById('map')

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
    center: latlng,
    mapTypeId: google.maps.MapTypeId.ROADMAP,
    styles: mapTypeStyle
  }

  map = new google.maps.Map(map_tag, options)

  register_event = (event_type) ->
    google.maps.event.addListener map, event_type, (e) ->
      projection = map.getProjection()
      zoomLevel = map.getZoom()
      latLng = e.latLng
      world_xy = projection.fromLatLngToPoint(latLng)
      multiplier = 1 << zoomLevel
      pixel_xy = [
        Math.round(world_xy.x * multiplier),
        Math.round(world_xy.y * multiplier)
      ]
      $(document).trigger('opencensus:' + event_type, [pixel_xy])

  register_event(event_type) for event_type in [ 'mousemove', 'click' ]

  google.maps.event.addListener map, 'mouseout', (e) ->
    $(document).trigger('opencensus:mouseout')

  svgMapType = new SvgMapType(new google.maps.Size(256, 256))
  map.overlayMapTypes.insertAt(0, svgMapType)
