#= require jquery
#= require json2
#= require raphael

#= require globals
#= require state

globals = window.OpenCensus.globals
state = window.OpenCensus.state

# Save some object creation
polygon_style_without_fill = { stroke: globals.style.stroke, 'stroke-width': globals.style['stroke-width'] }
polygon_style_with_fill = { stroke: globals.style.stroke, 'stroke-width': globals.style['stroke-width'], fill: undefined }

class MapTile
  constructor: (@tileSize, @coord, @zoom, div) ->
    @zoomFactor = Math.pow(2, @zoom)
    @multiplier = @zoomFactor / 360
    @topLeftGlobalPoint = [ @coord.x * @tileSize.width, @coord.y * @tileSize.height ]
    @paper = Raphael(div, @tileSize.width, @tileSize.height)
    @utfgrid = {}
    @regionData = {}
    div.id = this.id()

    this.requestData()

    event_class = this.id()
    $(document).on("opencensus:mousemove.#{event_class}", (e, params) => this.onMouseMove(params))
    $(document).on("opencensus:click.#{event_class}", (e, params) => this.onClick(params))
    $(document).on("opencensus:mouseout.#{event_class}", (e, params) => this.onMouseOut(params))
    $(document).on("opencensus:regionhoverin.#{event_class}", (e, params) => this.onRegionHoverIn(params))
    $(document).on("opencensus:regionhoverout.#{event_class}", (e, params) => this.onRegionHoverOut(params))

  requestData: () ->
    this.dataRequest = jQuery.ajax({
      url: this.url(),
      dataType: 'json',
      success: (data) => this.handleData(data)
    })

  drawPolygon: (coordinates) ->
    ring_strings = []

    for ring_coordinates in coordinates
      strings = []

      lonlat = ring_coordinates.shift()
      xy = this.lonlatToPointOnTile(lonlat)
      strings.push('M')
      strings.push(xy[0].toFixed(2))
      strings.push(xy[1].toFixed(2))
      strings.push('L')

      for lonlat in ring_coordinates
        xy = this.lonlatToPointOnTile(lonlat)
        strings.push(xy[0].toFixed(2))
        strings.push(xy[1].toFixed(2))

      strings.push('Z ')

      ring_strings.push(strings.join(' '))

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
    delete this.dataRequest

    @utfgrid = data.utfgrid
    @regionData = {}

    @paper.canvas.style.display = 'none'

    for feature in data.features
      id = feature.id
      properties = feature.properties
      @paper.setStart()
      this.drawGeometry(feature.geometry)
      geometry = @paper.setFinish()

      fill = this.getFillForStatistics(properties.statistics)

      if fill == 'none'
        geometry.attr(polygon_style_without_fill)
        geometry.hide()
      else
        polygon_style_with_fill.fill = fill
        geometry.attr(polygon_style_with_fill)

      @regionData[id] = { id: id, properties: properties, geometry: geometry }

    @paper.canvas.style.display = ''

  getFillForStatistics: (statistics) ->
    return 'none' if !statistics

    yearStatistics = statistics[state.year.toString()]
    return 'none' if !yearStatistics

    value = yearStatistics && yearStatistics[state.indicator.name]
    return 'none' if !value

    bucket = state.indicator.bucketForValue(value.value)
    return 'none' if bucket is undefined

    globals.style.buckets[bucket]

  restyle: () ->
    for id, region of @regionData
      properties = region.properties
      geometry = region.geometry

      fill = this.getFillForStatistics(statistics)
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

    return undefined unless @utfgrid.grid

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
    return if tilePoint is undefined

    region = this.tilePointToRegion(tilePoint)

    if !region && @hover_region_id
      $(document).trigger('opencensus:regionhoverout')

    if region && (!@hover_region_id || region.id != @hover_region_id)
      $(document).trigger('opencensus:regionhoverout') if @hover_region_id
      $(document).trigger('opencensus:regionhoverin', [region.id, region.properties])

  onMouseOut: () ->
    $(document).trigger('opencensus:regionhoverout', [@hover_region_id]) if @hover_region_id && @glow

  onRegionHoverIn: (region_id, properties) ->
    @hover_region_id = region_id

    region = @regionData[region_id]
    if region # if this tile contains at least part of the region
      @paper.setStart()
      # We can't use region.geometry.clone() because it produces warnings in Google Chrome 17.0.963.12 dev, Raphael 2.0.1
      region.geometry.forEach (geometry) =>
        path = geometry.attr('path')
        @paper.path(path).attr({
          stroke: '#000000',
          'stroke-width': '2px'
        })
      @glow = @paper.setFinish()

  onRegionHoverOut: () ->
    delete @hover_region_id
    if @glow
      @glow.remove()
      delete @glow

  onClick: (globalPoint) ->
    tilePoint = this.globalPointToTilePoint(globalPoint)
    return if tilePoint is undefined
    region = this.tilePointToRegion(tilePoint)
    $(document).trigger('opencensus:regionclick', [region])

  destroy: () ->
    this.dataRequest.abort() if this.dataRequest

    event_class = this.id()
    $(document).off(".#{event_class}")

window.SvgMapType = (@tileSize) ->

window.SvgMapType.Instances = {}

window.SvgMapType.prototype.getTile = (coord, zoom, ownerDocument) ->
  div = ownerDocument.createElement('div')
  div.style.width = "#{@tileSize.width}px"
  div.style.height = "#{@tileSize.height}px"
  $(div).css('opacity', globals.style.opacity)

  tile = new MapTile(@tileSize, coord, zoom, div)
  window.SvgMapType.Instances[tile.id()] = tile

  div

window.SvgMapType.prototype.releaseTile = (div) ->
  tile_id = div.childNodes[0].id
  tile = window.SvgMapType.Instances[tile_id]
  tile.destroy() if tile
  window.SvgMapType.Instances[tile_id] = undefined

  div.removeChild(div.childNodes[0])
