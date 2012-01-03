#= require jquery
#= require json2

#= require globals
#= require state

globals = window.OpenCensus.globals
state = window.OpenCensus.state

class Projection
  constructor: (@tileSize, @coord, @zoom) ->
    @zoomFactor = Math.pow(2, @zoom)
    @multiplier = @zoomFactor / 360
    @topLeftGlobalPoint = [ @coord.x * @tileSize.width, @coord.y * @tileSize.height ]

  lat2y: (lat) ->
    # http://wiki.openstreetmap.org/wiki/Mercator#ActionScript_and_JavaScript
    180 / Math.PI * Math.log(Math.tan(Math.PI / 4 + lat * Math.PI / 360))

  lonlatToGlobalPoint: (lonlat) ->
    [
      @multiplier * (lonlat[0] + 180),
      @multiplier * (180 - this.lat2y(lonlat[1]))
    ]

  lonlatToPointOnTile: (lonlat) ->
    c = this.lonlatToGlobalPoint(lonlat)
    #console.log(lonlat, c, @zoomFactor, [ @tileSize.width * c[0], @tileSize.height * c[1] ], @coord, @topLeftGlobalPoint)
    [
      @tileSize.width * c[0] - @topLeftGlobalPoint[0],
      @tileSize.height * c[1] - @topLeftGlobalPoint[1]
    ]

addMultiPolygonToSvgNode = (mapType, svgNode, multiPolygon, lonlatToPointOnTile) ->
  g = document.createElementNS(svgns, 'g')
  g.className = 'multi-polygon'
  svgNode.appendChild(g)

  for polygon in multiPolygon.coordinates
    linearRingStrings = []
    for linearRing in polygon
      pointStrings = []
      for lonlat in linearRing
        point = lonlatToPointOnTile(lonlat)
        pointStrings.push("#{point[0]},#{point[1]}")
      linearRingStrings.push(pointStrings)

    if linearRingStrings.length == 1
      p = document.createElementNS(svgns, 'polygon')
      p.setAttribute('points', linearRingStrings[0].join(' '))
      g.appendChild(p)
    else
      pathStrings = []
      pathStrings.push("M#{linearRing[0]}L#{linearRing[1..-1].join(' ')}Z") for linearRing in linearRingStrings

      path = document.createElementNS(svgns, 'path')
      path.className = 'polygon'
      path.setAttribute('fill-rule', 'evenodd')
      path.setAttribute('d', pathStrings.join(''))
      g.appendChild(path)

requestSvgData = (url, coord, zoom, callback) ->
  jQuery.ajax({
    url: url,
    dataType: 'json',
    success: callback
  })

setGStyleForProperties = (g, properties, style) ->
  yearProperties = properties[state.year.toString()]
  value = yearProperties && yearProperties[state.indicator.name]

  if !value && value isnt 0
    g.style.display = 'none'
    return

  bucket = state.indicator.bucketForValue(value)
  if bucket is undefined
    g.style.display = 'none'
    return

  fill = style.buckets[bucket]
  g.style.display = 'svg-g'
  g.style.fill = fill

populateSvgWithData = (document, svgRoot, data, lonlatToPointOnTile) ->
  style = $(document.getElementById('map')).data('opencensus-style')
  svgRoot.style.opacity = style.opacity

  workStack = [ { svgNode: svgRoot, dataNode: data } ]

  while workStack.length > 0
    work = workStack.pop()
    svgNode = work.svgNode
    dataNode = work.dataNode

    switch dataNode.type
      when 'FeatureCollection'
        features = dataNode.features
        workStack.unshift({ svgNode: svgNode, dataNode: subNode }) for subNode in features
      when 'Feature'
        g = document.createElementNS(svgns, 'g')
        g.className = "feature #{dataNode.properties.type}"
        g.id = "#{dataNode.id}"
        propertiesString = window.JSON.stringify(dataNode.properties)
        g.setAttribute('data-properties', propertiesString)
        g.style.stroke = style.stroke
        g.style.strokeWidth = '1px'
        setGStyleForProperties(g, dataNode.properties, style)
        svgNode.appendChild(g)

        workStack.unshift({ svgNode: g, dataNode: dataNode.geometry })
      when 'GeometryCollection'
        geometries = dataNode.geometries
        if geometries.length
          g = document.createElementNS(svgns, 'g')
          g.className = 'geometry-collection'
          svgNode.appendChild(g)

          workStack.unshift({ svgNode: g, dataNode: subNode }) for subNode in geometries
      when 'MultiPolygon'
        addMultiPolygonToSvgNode(document, svgNode, dataNode, lonlatToPointOnTile)
      when 'Polygon'
        addMultiPolygonToSvgNode(document, svgNode, { coordinates: [ dataNode.coordinates ] }, lonlatToPointOnTile)
      else
        # ignore

window.SvgMapType = (@tileSize) ->

window.SvgMapType.prototype.getTileUrl = (coord, zoom) ->
  "#{globals.json_tile_url}/regions/#{zoom}/#{coord.x}/#{coord.y}.geojson"

window.SvgMapType.prototype.getTile = (coord, zoom, ownerDocument) ->
  div = ownerDocument.createElement('div')
  div.style.width = "#{@tileSize.width}px"
  div.style.height = "#{@tileSize.height}px"

  svg = ownerDocument.createElementNS(svgns, 'svg')
  svg.setAttribute('width', "#{@tileSize.width}")
  svg.setAttribute('height', "#{@tileSize.height}")

  url = this.getTileUrl(coord, zoom)
  projection = new Projection(@tileSize, coord, zoom)

  svg.addEventListener 'SVGLoad', (e) ->
    root = div.childNodes[0]
    requestSvgData url, coord, zoom, (data) ->
      populateSvgWithData(document, root, data, (lonlat) -> projection.lonlatToPointOnTile(lonlat))

  window.svgweb.appendChild(svg, div)

  div

window.SvgMapType.prototype.releaseTile = (div) ->
  window.svgweb.removeChild(div.childNodes[0], div)
