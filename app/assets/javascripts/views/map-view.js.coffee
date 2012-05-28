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
      #styles: mapTypeStyle,
    }

    @map = new google.maps.Map(@div, options)

    svgMapType = new SvgMapType(new google.maps.Size(256, 256))
    @map.overlayMapTypes.insertAt(0, svgMapType)

    state.onPoint1Changed('map_view', this.onPoint1Changed, this)
    state.onPoint2Changed('map_view', this.onPoint2Changed, this)

    @markers = {
      '1': new google.maps.Marker({
        clickable: false,
        draggable: true,
        flat: true,
        map: @map,
        position: new google.maps.LatLng(0, 0),
        visible: false,
      }),
      '2': new google.maps.Marker({
        clickable: false,
        draggable: true,
        flat: true,
        map: @map,
        position: new google.maps.LatLng(0, 0),
        visible: false,
      })
    }

  _onPointNChanged: (n, point) ->
    marker = @markers["#{n}"]

    if !point?
      marker.setVisible(false)
    else
      google_point = new google.maps.LatLng(point.latlng.latitude, point.latlng.longitude)

      marker.setPosition(google_point)
      marker.setVisible(true)

      if !@map.getBounds().contains(google_point)
        newBounds = @map.getBounds().extend(google_point)
        @map.setBounds(newBounds)

  onPoint1Changed: (point) ->
    this._onPointNChanged(1, point)

  onPoint2Changed: (point) ->
    this._onPointNChanged(2, point)

  onMapEvent: (event_type, callback) ->
    google.maps.event.addListener(@map, event_type, callback)

  onMarker1PositionChanged: (callback) ->
    google.maps.event.addListener @markers['1'], 'dragend', () =>
      callback(@markers['1'].getPosition())

  onMarker2PositionChanged: (callback) ->
    google.maps.event.addListener @markers['2'], 'dragend', () =>
      callback(@markers['2'].getPosition())

window.OpenCensus.views.MapView = MapView
