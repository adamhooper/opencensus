#= require jquery
#= require json2
#= require raphael

#= require globals
#= require state

globals = window.OpenCensus.globals
state = window.OpenCensus.state

class MapTile
  constructor: (@tileSize, @coord, @zoom, div) ->
    @zoomFactor = Math.pow(2, @zoom)
    @multiplier = @zoomFactor / 360
    @topLeftGlobalPoint = [ @coord.x * @tileSize.width, @coord.y * @tileSize.height ]
    @paper = Raphael(div, @tileSize.width, @tileSize.height)
    @paper.canvas.style.opacity = "#{globals.style.opacity * 100}%"
    @utfgrid = {}
    @regionData = {}
    div.id = this.id()

    event_class = this.id()
    $(document).on("opencensus:mousemove.#{event_class}", (e, params) => this.onMouseMove(params))
    $(document).on("opencensus:click.#{event_class}", (e, params) => this.onClick(params))
    $(document).on("opencensus:mouseout.#{event_class}", (e, params) => this.onMouseOut(params))
    $(document).on("opencensus:regionhoverin.#{event_class}", (e, params) => this.onRegionHoverIn(params))
    $(document).on("opencensus:regionhoverout.#{event_class}", (e, params) => this.onRegionHoverOut(params))

    this.requestData()

  requestData: () ->
    jQuery.ajax({
      url: this.url(),
      dataType: 'json',
      success: (data) => this.handleData(data)
    })

  drawPolygon: (coordinates) ->
    ring_strings = []

    for ring_coordinates in coordinates
      strings = []

      for lonlat in ring_coordinates
        xy = this.lonlatToPointOnTile(lonlat)
        strings.push(xy[0].toFixed(2) + ' ' + xy[1].toFixed(2))

      ring_strings.push("M#{strings[0]}L#{strings[1..-1].join(' ')}Z")

    @paper.path(ring_strings.join(''))

  drawGeometry: (geometry) ->
    switch geometry.type
      when  'GeometryCollection'
        this.drawGeometry(subgeometry) for subgeometry in geometry.geometries
      when 'MultiPolygon'
        this.drawPolygon(subcoordinates) for subcoordinates in geometry.coordinates
      when 'Polygon'
        this.drawPolygon(geometry.coordinates)
    
  handleData: (data) ->
    @utfgrid = data.utfgrid
    @regionData = {}

    @paper.canvas.style.display = 'none'

    for feature in data.features
      id = feature.id
      properties = feature.properties
      @paper.setStart()
      this.drawGeometry(feature.geometry)
      geometry = @paper.setFinish()

      fill = this.getFillForProperties(properties)

      if fill == 'none'
        geometry.attr({ stroke: globals.style.stroke, 'stroke-width': globals.style['stroke-width'] })
        geometry.hide()
      else
        geometry.attr({ stroke: globals.style.stroke, 'stroke-width': globals.style['stroke-width'], fill: fill })

      @regionData[id] = { id: id, properties: properties, geometry: geometry }

    @paper.canvas.style.display = ''

  getFillForProperties: (properties) ->
    yearProperties = properties[state.year.toString()]
    value = yearProperties && yearProperties[state.indicator.name]

    if !value && value isnt 0
      'none'
    else
      bucket = state.indicator.bucketForValue(value)

      if bucket is undefined
        'none'
      else
        globals.style.buckets[bucket]

  styleGeometryWithProperties: (geometry, properties) ->

  restyle: () ->
    for id, region of @regionData
      properties = region.properties
      geometry = region.geometry

      fill = this.getFillForProperties(properties)
      if fill == 'none'
        geometry.hide()
      else
        geometry.attr({ fill: fill })
        geometry.show()

  id: () ->
    "MapTile-#{@zoom}-#{@coord.x}-#{@coord.y}"

  url: () ->
    "#{globals.json_tile_url}/regions/#{@zoom}/#{@coord.x}/#{@coord.y}.geojson"

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

  globalPointToTilePoint: (globalPoint) ->
    ret = [ globalPoint[0] - @topLeftGlobalPoint[0], globalPoint[1] - @topLeftGlobalPoint[1] ]
    if ret[0] < 0 || ret[1] < 0 || ret[0] >= @tileSize.width || ret[1] >= @tileSize.height
      undefined
    else
      ret

  tilePointToRegion: (tilePoint) ->
    [ column, row ] = tilePoint

    grid = @utfgrid.grid
    keys = @utfgrid.keys

    encoded_id = grid[row].charCodeAt(column)
    id = encoded_id
    id -= 1 if id >= 93
    id -= 1 if id >= 35
    id -= 32

    key = keys[id]
    @regionData[key]

  onMouseMove: (globalPoint) ->
    tilePoint = this.globalPointToTilePoint(globalPoint)
    if tilePoint is undefined
      $(document).trigger('opencensus:regionhoverout', [@hover_region]) if @hover_region
      @hover_region = undefined
      return
    region = this.tilePointToRegion(tilePoint)

    if region != @hover_region
      $(document).trigger('opencensus:regionhoverout', [@hover_region]) if @hover_region
      @hover_region = region
      $(document).trigger('opencensus:regionhoverin', [region]) if @hover_region

  onMouseOut: () ->
    $(document).trigger('opencensus:regionhoverout', [@hover_region]) if @hover_region
    @hover_region = undefined

  onRegionHoverIn: (region) ->
    geometry = region.geometry
    geometry.attr({ stroke: 'green' })

  onRegionHoverOut: (region) ->
    geometry = region.geometry
    geometry.attr({ stroke: 'white' })

  onClick: (world_xy) ->
    tilePoint = this.globalPointToTilePoint(globalPoint)
    return if tilePoint is undefined
    region = this.tilePointToRegion(tilePoint)
    $(document).trigger('opencensus:regionclick', [region])

  destroy: () ->
    event_class = this.id()
    $(document).off(".#{event_class}")

window.SvgMapType = (@tileSize) ->

window.SvgMapType.Instances = {}

window.SvgMapType.prototype.getTile = (coord, zoom, ownerDocument) ->
  div = ownerDocument.createElement('div')
  div.style.width = "#{@tileSize.width}px"
  div.style.height = "#{@tileSize.height}px"
  $(div).attr('opacity', globals.style.opacity)

  tile = new MapTile(@tileSize, coord, zoom, div)
  window.SvgMapType.Instances[tile.id()] = tile

  div

window.SvgMapType.prototype.releaseTile = (div) ->
  tile_id = div.childNodes[0].id
  tile = window.SvgMapType.Instances[tile_id]
  tile.destroy() if tile
  window.SvgMapType.Instances[tile_id] = undefined

  div.removeChild(div.childNodes[0])
