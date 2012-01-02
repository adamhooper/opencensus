#= require jquery
#= require svg_map_type

$ ->
  latlng = new google.maps.LatLng(45.5, -73.5)
  zoom = 9

  map_tag = document.getElementById('map')

  # Generated using http://colorbrewer2.org/
  color_buckets = [ '#fef0d9', '#fdd49e', '#fdbb84', '#fc8d59', '#ef6548', '#d7301f', '#990000' ]

  $(map_tag).data('opencensus-style', { 'stroke': '#ffffff', 'stroke-width': '2px', 'opacity': 0.5, 'buckets': color_buckets });

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

  addOverlay = ->
    svgMapType = new SvgMapType(new google.maps.Size(256, 256))
    map.overlayMapTypes.insertAt(0, svgMapType)

  window.addEventListener('SVGLoad', addOverlay, false)
