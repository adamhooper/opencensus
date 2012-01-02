#= require jquery
#= require json2

BASE_URL = 'http://localhost:8000'

STATE = {
  indicator: {
    name: 'Population density',
    units: 'people per km2',
    buckets: [
      { min: 0, max: 0.400024243893569 },
      { min: 0.401275002320999, max: 3.16639865227046 },
      { min: 3.16668030439408, max: 10.9016112444292 },
      { min: 10.9090909090909, max: 38.3047210300429 },
      { min: 38.3783783783784, max: 96.7391304347826 },
      { min: 96.7741935483871, max: 175.257731958763 },
      { min: 175.586854460094, max: 2768.40916424653 }
    ]
    bucketForValue: (value) ->
      for bucket, i in this.buckets
        return i if value <= bucket.max
      return 0
  },
  year: 2006
}

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
  value = properties['' + STATE.year] && properties['' + STATE.year][STATE.indicator.name]

  if !value && value != 0
    g.style.display = 'none'
    return

  value = properties[STATE.year][STATE.indicator.name]
  bucket = STATE.indicator.bucketForValue(value)
  fill = style.buckets[bucket]

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
        features.reverse()
        workStack.push({ svgNode: svgNode, dataNode: subNode }) for subNode in features
      when 'Feature'
        g = document.createElementNS(svgns, 'g')
        g.className = "feature #{dataNode.properties.type}"
        g.id = "#{dataNode.id}"
        propertiesString = window.JSON.stringify(dataNode.properties)
        g.setAttribute('data-properties', propertiesString)
        g.style.stroke = style.stroke
        g.style.strokeWidth = '2px'
        setGStyleForProperties(g, dataNode.properties, style)
        svgNode.appendChild(g)

        workStack.push({ svgNode: g, dataNode: dataNode.geometry })
      when 'GeometryCollection'
        geometries = dataNode.geometries
        if geometries.length
          geometries.reverse()

          g = document.createElementNS(svgns, 'g')
          g.className = 'geometry-collection'
          svgNode.appendChild(g)

          workStack.push({ svgNode: g, dataNode: subNode }) for subNode in geometries
      when 'MultiPolygon'
        addMultiPolygonToSvgNode(document, svgNode, dataNode, lonlatToPointOnTile)
      when 'Polygon'
        addMultiPolygonToSvgNode(document, svgNode, { coordinates: [ dataNode.coordinates ] }, lonlatToPointOnTile)
      else
        # ignore

window.SvgMapType = (@tileSize) ->

window.SvgMapType.prototype.getTileUrl = (coord, zoom) ->
  "#{BASE_URL}/regions/#{zoom}/#{coord.x}/#{coord.y}.geojson"

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
