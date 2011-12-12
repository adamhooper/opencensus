#= require jquery
#= require svg_map_type

$ ->
  latlng = new google.maps.LatLng(45.5, -73.5)
  zoom = 6

  map_tag = document.getElementById('map')
  options = {
    zoom: zoom,
    center: latlng,
    mapTypeId: google.maps.MapTypeId.ROADMAP
  }

  map = new google.maps.Map(map_tag, options)

  addOverlay = ->
    svgMapType = new SvgMapType(new google.maps.Size(256, 256))
    map.overlayMapTypes.insertAt(0, svgMapType)

  window.addEventListener('SVGLoad', addOverlay, false)
