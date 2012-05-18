#= require jquery
#= require json2
#= require raphael

#= require app
#= require globals
#= require state
#= require models/region
#= require raphael-optimizations

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
polygon_style_base = {
  stroke: globals.style.stroke,
  'stroke-width': globals.style['stroke-width']
}
overlay_polygon_styles = {
  hover: $.extend({}, polygon_style_base, globals.hover_style),
  selected: $.extend({}, polygon_style_base, globals.selected_style),
}

class MapTile
  constructor: (@tileSize, @coord, @zoom, @div) ->
    # http://www.maptiler.org/google-maps-coordinates-tile-bounds-projection/
    zoomFactor = Math.pow(2, @zoom)
    @pixelsPerMeterHorizontal = @tileSize.width * zoomFactor / (20037508.342789244 * 2)
    @pixelsPerMeterVertical = @tileSize.height * zoomFactor / (20037508.342789244 * 2)
    leftGlobalMeter = (-20037508.342789244 + @coord.x * @tileSize.width / @pixelsPerMeterHorizontal)
    topGlobalMeter = (-20037508.342789244 + @coord.y * @tileSize.height / @pixelsPerMeterVertical)
    @topLeftGlobalPixel = [ leftGlobalMeter * @pixelsPerMeterHorizontal, topGlobalMeter * @pixelsPerMeterVertical ]

    @interaction_grids = undefined
    @regions = {} # json_id => { region: region, geometry: GeoJSON geometry, element: Raphael element }
    @overlayElements = {}
    @mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(state.indicator)

    childDiv = div.ownerDocument.createElement('div')
    childDiv.style.position = 'absolute'
    childDiv.style.top = 0
    childDiv.style.bottom = 0
    childDiv.style.left = 0
    childDiv.style.right = 0
    @div.appendChild(childDiv)
    @paper = Raphael(childDiv, @tileSize.width, @tileSize.height)

    overlayDiv = div.ownerDocument.createElement('div')
    overlayDiv.style.position = 'absolute'
    overlayDiv.style.top = 0
    overlayDiv.style.bottom = 0
    overlayDiv.style.left = 0
    overlayDiv.style.right = 0
    @div.appendChild(overlayDiv)
    @overlayPaper = Raphael(overlayDiv, @tileSize.width, @tileSize.height)

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

  drawPolygon: (paper, coordinates, style) ->
    strings = []

    moveto = Raphael.optimized_path_creation_strings.moveto
    lineto = Raphael.optimized_path_creation_strings.lineto
    close = Raphael.optimized_path_creation_strings.close

    for ring_coordinates in coordinates
      for globalMeter, i in ring_coordinates
        if i == 0
          strings.push(moveto)
        else
          strings.push(lineto)

        # Optimize: insert globalMeterToTilePixel() inline
        x = globalMeter[0] * @pixelsPerMeterHorizontal - @topLeftGlobalPixel[0]
        y = -globalMeter[1] * @pixelsPerMeterVertical - @topLeftGlobalPixel[1]

        strings.push(x.toFixed(2))
        strings.push(',')
        strings.push(y.toFixed(2))

      strings.push(close)

    path = strings.join('')

    paper.optimized_path(path, style)

  drawGeometry: (paper, geometry, style) ->
    switch geometry.type
      when  'GeometryCollection'
        this.drawGeometry(paper, subgeometry, style) for subgeometry in geometry.geometries
      when 'MultiPolygon'
        this.drawPolygon(paper, subcoordinates, style) for subcoordinates in geometry.coordinates
      when 'Polygon'
        this.drawPolygon(paper, geometry.coordinates, style)

  getFillForRegion: (region) ->
    datum = region.getDatum(state.year, @mapIndicator)
    return undefined unless datum? && datum.value?
    bucket = @mapIndicator.bucketForValue(datum.value)
    return undefined unless bucket? && @mapIndicator.bucket_colors?

    @mapIndicator.bucket_colors[bucket] || globals.style.buckets[bucket]

  handleData: (data) ->
    delete this.dataRequest

    for feature in data.features
      properties = feature.properties
      region = new Region(feature.id, properties.name, properties.parents, properties.statistics)
      region_store.add(region)
      @regions[region.id] = { region: region, geometry: feature.geometry }

    @interaction_grids = new InteractionGridArray(@tileSize, data.utfgrids)

    this.drawRegions()

  drawRegions: () ->
    @paper.canvas.style.display = 'none'

    style = $.extend({}, polygon_style_base)

    for regionId, regionData of @regions
      fill = this.getFillForRegion(regionData.region)
      style.fill = fill || 'none'

      @paper.setStart()
      this.drawGeometry(@paper, regionData.geometry, style)
      element = @paper.setFinish()
      regionData.element = element

      element.hide() if !fill?

    @paper.canvas.style.display = ''

    this.onHoverRegionChanged(state.hover_region)
    this.onRegionChanged(state.region)

  getFillForStatistics: (statistics) ->
    return 'none' if !statistics
    year_string = state.year.toString()
    year_statistics = statistics[year_string]
    return 'none' if !year_statistics
    datum = year_statistics[@mapIndicator.name]
    return 'none' if !datum?

    bucket = @mapIndicator.bucketForValue(datum.value)
    return 'none' if bucket is undefined

    @mapIndicator.bucket_colors && @mapIndicator.bucket_colors[bucket] || globals.style.buckets[bucket]

  restyle: () ->
    for regionId, regionData of @regions
      region = regionData.region
      element = regionData.element

      fill = this.getFillForRegion(region)
      if fill == 'none'
        element.hide()
      else
        element.attr({ fill: fill })
        element.show()

  id: () ->
    "MapTile-#{@zoom}-#{@coord.x}-#{@coord.y}"

  url: () ->
    base_url = globals.json_tile_url.replace('#{n}', ('' + ((@coord.x % 2) * 2 + (@coord.y % 2))))
    "#{base_url}/#{@zoom}/#{@coord.x}/#{@coord.y}.geojson"

  globalMeterToTilePixel: (globalMeter) ->
    [
      globalMeter[0] * @pixelsPerMeterHorizontal - @topLeftGlobalPixel[0],
      - globalMeter[1] * @pixelsPerMeterVertical - @topLeftGlobalPixel[1]
    ]

  globalMeterToTilePixelOrUndefined: (globalMeter) ->
    ret = this.globalMeterToTilePixel(globalMeter)
    if ret[0] < 0 || ret[1] < 0 || ret[0] >= @tileSize.width || ret[1] >= @tileSize.height
      undefined
    else
      ret

  tilePixelToRegion: (tilePixel) ->
    [ column, row ] = tilePixel

    return undefined unless @interaction_grids?
    @interaction_grids.pointToRegionWithDatum(column, row, state.year, @mapIndicator)

  onMouseMove: (globalMeter) ->
    tilePixel = this.globalMeterToTilePixelOrUndefined(globalMeter)

    if tilePixel?
      @lastMouseMoveWasOnThisTile = true

      region = this.tilePixelToRegion(tilePixel) # may be undefined
      state.setHoverRegion(region) # Will only set if it's different
    else
      @lastMouseMoveWasOnThisTile = false

    true

  onMouseOut: () ->
    if @lastMouseMoveWasOnThisTile
      @lastMouseMoveWasOnThisTile = false
      state.setHoverRegion(undefined)

    true

  setOverlayElement: (name, region) ->
    if @overlayElements[name]?
      @overlayElements[name].remove()
      delete @overlayElements[name]

    if region
      geometry = @regions[region.id]?.geometry

      if geometry?
        @overlayPaper.setStart()
        # We can't use region.geometry.clone() because it's in a different document
        this.drawGeometry(@overlayPaper, geometry, overlay_polygon_styles[name])
        @overlayElements[name] = @overlayPaper.setFinish()

  onHoverRegionChanged: (hover_region) ->
    this.setOverlayElement('hover', hover_region)
    @overlayElements.hover?.toBack()

  onRegionChanged: (selected_region) ->
    this.setOverlayElement('selected', selected_region)
    @overlayElements.selected?.toFront()

  onIndicatorChanged: (indicator) ->
    @mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(indicator)
    this.restyle()

  onClick: (globalMeter) ->
    tilePixel = this.globalMeterToTilePixelOrUndefined(globalMeter)
    return if !tilePixel?

    region = this.tilePixelToRegion(tilePixel)
    state.setRegion(region)

  destroy: () ->
    this.dataRequest.abort() if this.dataRequest?

    event_class = this.id()
    $(document).off(".#{event_class}")

    for region_id, regionData of @regions
      region_store.remove(region_id)

    @regions = {}
    @overlayElements = {}
    @overlayPaper.remove()
    @paper.remove()
    $(@div).empty()
    delete @div

window.SvgMapType = (@tileSize) ->

window.SvgMapType.Instances = {}

window.SvgMapType.prototype.getTile = (coord, zoom, ownerDocument) ->
  div = ownerDocument.createElement('div')
  div.style.width = "#{@tileSize.width}px"
  div.style.height = "#{@tileSize.height}px"
  div.style.position = 'relative'
  $(div).css('opacity', globals.style.opacity)

  tile = new MapTile(@tileSize, coord, zoom, div)
  div.id = tile.id()
  window.SvgMapType.Instances[tile.id()] = tile

  div

window.SvgMapType.prototype.releaseTile = (div) ->
  tile_id = div.id
  tile = window.SvgMapType.Instances[tile_id]
  tile.destroy() if tile?
  window.SvgMapType.Instances[tile_id] = undefined
  div.id = undefined
