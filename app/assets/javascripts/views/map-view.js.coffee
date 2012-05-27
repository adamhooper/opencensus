#= require jquery

#= require state
#= require globals
#= require svg_map_type

state = window.OpenCensus.state
globals = window.OpenCensus.globals

class MapView
  constructor: (@div) ->
    latlng = new google.maps.LatLng(globals.defaults.position.latitude, globals.defaults.position.longitude)
    zoom = globals.defaults.position.zoom

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

    state.onPointChanged('map_view', this.onPointChanged, this)

    @marker = new google.maps.Marker({
      clickable: false,
      draggable: true,
      flat: true,
      map: @map,
      position: new google.maps.LatLng(0, 0),
      visible: false,
    })

  onPointChanged: (point) ->
    if !point?
      @marker.setVisible(false)
    else
      google_point = new google.maps.LatLng(point.latlng.latitude, point.latlng.longitude)
      if !@map.getBounds().contains(google_point)
        @map.setCenter(point)
      @marker.setPosition(google_point)
      @marker.setVisible(true)

  onMapEvent: (event_type, callback) ->
    google.maps.event.addListener(@map, event_type, callback)

window.OpenCensus.views.MapView = MapView
