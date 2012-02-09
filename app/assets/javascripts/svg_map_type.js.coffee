#= require jquery
#= require json2
#= require raphael

#= require app
#= require globals
#= require state
#= require models/region

globals = window.OpenCensus.globals
region_types = globals.region_types
state = window.OpenCensus.state
Region = window.OpenCensus.models.Region
region_store = globals.region_store

class InteractionGrid
  constructor: (@tileSize, utfgrid) ->
    @grid = utfgrid.grid
    @keys = utfgrid.keys
    @heightFactor = @grid.length / @tileSize.height
    @widthFactor = @grid[0].length / @tileSize.width

  encodedIdToRegionId: (id) ->
    id -= 1 if id >= 93
    id -= 1 if id >= 35
    id -= 32

    @keys[id]

  pointToRegionId: (column, row) ->
    grid_column = Math.floor(@widthFactor * column)
    grid_row = Math.floor(@heightFactor * row)

    encoded_id = @grid[grid_row].charCodeAt(grid_column)
    this.encodedIdToRegionId(encoded_id)

class InteractionGridArray
  constructor: (@tileSize, utfgrids) ->
    @interaction_grids = (new InteractionGrid(@tileSize, utfgrid) for utfgrid in utfgrids)

  pointToRegionIds: (column, row) ->
    region_ids = (grid.pointToRegionId(column, row) for grid in @interaction_grids)
    $.unique(region_ids)

  # Returns the "best" Region--using region_types ordering
  pointToRegionWithDatum: (column, row, year, indicator) ->
    region_ids = this.pointToRegionIds(column, row)

    best_region = undefined
    best_index = -1

    for region_id in region_ids
      region = region_store.getNearestRegionWithDatum(region_id, year, indicator)
      if region
        index = region_types.indexOfName(region.type)
        if index > best_index
          best_region = region
          best_index = index

    best_region

# Save some object creation
polygon_style_without_fill = { stroke: globals.style.stroke, 'stroke-width': globals.style['stroke-width'] }
polygon_style_with_fill = { stroke: globals.style.stroke, 'stroke-width': globals.style['stroke-width'], fill: undefined }

class MapTile
  constructor: (@tileSize, @coord, @zoom, div) ->
    @zoomFactor = Math.pow(2, @zoom)
    @multiplier = @zoomFactor / 360
    @topLeftGlobalPoint = [ @coord.x * @tileSize.width, @coord.y * @tileSize.height ]
    @paper = Raphael(div, @tileSize.width, @tileSize.height)
    @interaction_grids = undefined
    @regionIdToGeometry = {}
    @mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(state.indicator)
    div.id = this.id()

    this.requestData()

    event_class = this.id()
    $(document).on("opencensus:click.#{event_class}", (e, params) => this.onClick(params))
    $(document).on("opencensus:mousemove.#{event_class}", (e, params) => this.onMouseMove(params))
    $(document).on("opencensus:mouseout.#{event_class}", (e, params) => this.onMouseOut(params))
    state.onHoverRegionChanged(event_class, this.onHoverRegionChanged, this)
    state.onRegionChanged(event_class, this.onRegionChanged, this)
    state.onIndicatorChanged(event_class, this.onIndicatorChanged, this)

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

      region = new Region(properties.type, properties.uid, properties.name, properties.parents, properties.statistics)
      region_store.add(region)
      @regionIdToGeometry[id] = geometry

    @paper.canvas.style.display = ''

    @interaction_grids = new InteractionGridArray(@tileSize, data.utfgrids)

  getFillForStatistics: (statistics) ->
    return 'none' if !statistics
    year_string = state.year.toString()
    year_statistics = statistics[year_string]
    return 'none' if !year_statistics
    datum = year_statistics[@mapIndicator.name]
    return 'none' if !datum

    bucket = @mapIndicator.bucketForValue(datum.value)
    return 'none' if bucket is undefined

    @mapIndicator.bucket_colors && @mapIndicator.bucket_colors[bucket] || globals.style.buckets[bucket]

  restyle: () ->
    for id, geometry of @regionIdToGeometry
      region = region_store.get(id)

      fill = this.getFillForStatistics(region.statistics)
      if fill == 'none'
        geometry.hide()
      else
        geometry.attr({ fill: fill })
        geometry.show()

  id: () ->
    "MapTile-#{@zoom}-#{@coord.x}-#{@coord.y}"

  url: () ->
    base_url = globals.json_tile_url.replace('#{n}', ('' + ((@coord.x % 2) * 2 + (@coord.y % 2))))
    "#{base_url}/regions/#{@zoom}/#{@coord.x}/#{@coord.y}.geojson"

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

    return undefined unless @interaction_grids
    @interaction_grids.pointToRegionWithDatum(column, row, state.year, @mapIndicator)

  onMouseMove: (globalPoint) ->
    tilePoint = this.globalPointToTilePoint(globalPoint)
    if tilePoint is undefined
      @lastMouseMoveWasOnThisTile = false
      return
    @lastMouseMoveWasOnThisTile = true

    region = this.tilePointToRegion(tilePoint)

    if !region && @hover_region
      state.setHoverRegion(undefined)

    if region && (!@hover_region || !region.equals(@hover_region))
      state.setHoverRegion(region)

  onMouseOut: () ->
    if @lastMouseMoveWasOnThisTile && @hover_region
      state.setHoverRegion(undefined)
    @lastMouseMoveWasOnThisTile = false

  onHoverRegionChanged: (hover_region) ->
    if @hover_region
      delete @hover_region
      if @hover_region_glow
        @hover_region_glow.remove()
        delete @hover_region_glow

    if hover_region
      @hover_region = hover_region

      geometrySet = @regionIdToGeometry[hover_region.id()]
      if geometrySet # if this tile contains at least part of the region
        @paper.setStart()
        # We can't use region.geometry.clone() because it produces warnings in Google Chrome 17.0.963.12 dev, Raphael 2.0.1
        geometrySet.forEach (geometry) =>
          path = geometry.attr('path')
          @paper.path(path).attr({
            stroke: '#000000'
          })
        @hover_region_glow = @paper.setFinish()

  onRegionChanged: (selected_region) ->
    if @selected_region
      delete @selected_region
      if @selected_region_glow
        @selected_region_glow.remove()
        delete @selected_region_glow

    if selected_region
      @selected_region = selected_region

      geometrySet = @regionIdToGeometry[selected_region.id()]
      if geometrySet # if this tile contains at least part of the region
        @paper.setStart()
        # We can't use region.geometry.clone() because it produces warnings in Google Chrome 17.0.963.12 dev, Raphael 2.0.1
        geometrySet.forEach (geometry) =>
          path = geometry.attr('path')
          @paper.path(path).attr({
            stroke: '#000000',
            'stroke-width': '2.5px'
          })
        @selected_region_glow = @paper.setFinish()

  onIndicatorChanged: (indicator) ->
    @mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(indicator)
    this.restyle()

  onClick: (globalPoint) ->
    tilePoint = this.globalPointToTilePoint(globalPoint)
    return if tilePoint is undefined
    region = this.tilePointToRegion(tilePoint)

    state.setRegion(region)

  destroy: () ->
    this.dataRequest.abort() if this.dataRequest

    event_class = this.id()
    $(document).off(".#{event_class}")

    for region_id, geometry of @regionIdToGeometry
      region_store.remove(region_id)

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
