#= require jquery
#= require json2

BASE_URL = 'http://localhost:8000'

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

populateSvgWithData = (document, svgRoot, data, lonlatToPointOnTile) ->
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
        g.className = 'feature'
        g.id = dataNode.id
        propertiesString = window.JSON.stringify(dataNode.properties)
        g.setAttribute('data-properties', propertiesString)
        svgNode.appendChild(g)

        workStack.push({ svgNode: g, dataNode: dataNode.geometry })
      when 'GeometryCollection'
        g = document.createElementNS(svgns, 'g')
        g.className = 'geometry-collection'
        svgNode.appendChild(g)

        geometries = dataNode.geometries
        geometries.reverse()
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
