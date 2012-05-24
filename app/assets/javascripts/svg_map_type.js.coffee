#= require jquery
#= require json2

#= require app
#= require globals
#= require state
#= require models/region
#= require paper
#= require parse_opencensus_geojson

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

  pointToRegionList: (column, row) ->
    child_region_ids = (grid.pointToRegionId(column, row) for grid in @interaction_grids)
    region_store.getRegionListFromChildRegionIds(child_region_ids)

  # Returns the "best" Region--using region_types ordering
  pointToRegionWithDatum: (column, row, indicator) ->
    region_list = this.pointToRegionList(column, row)
    region_store.getBestRegionWithDatumInRegionList(region_list, indicator)

# Save some object creation
polygon_style_base = {
  stroke: globals.style.stroke,
  'stroke-width': globals.style['stroke-width']
}
overlay_polygon_styles = {
  hover: $.extend({}, polygon_style_base, globals.hover_style),
  region1: $.extend({}, polygon_style_base, globals.selected_style),
  region2: $.extend({}, polygon_style_base, globals.selected_style),
}

class MapTile
  constructor: (@tileSize, @coord, @zoom, @div) ->
    # http://www.maptiler.org/google-maps-coordinates-tile-bounds-projection/
    zoomFactor = Math.pow(2, @zoom)
    @pixelsPerMeterHorizontal = @tileSize.width * zoomFactor / (20037508.342789244 * 2)
    @pixelsPerMeterVertical = @tileSize.height * zoomFactor / (20037508.342789244 * 2)
    leftGlobalMeter = (-20037508.342789244 + @coord.x * @tileSize.width / @pixelsPerMeterHorizontal)
    topGlobalMeter = (20037508.342789244 - @coord.y * @tileSize.height / @pixelsPerMeterVertical)
    widthInMeters = @tileSize.width / @pixelsPerMeterHorizontal
    heightInMeters = @tileSize.height / @pixelsPerMeterVertical
    @topLeftGlobalPixel = [ leftGlobalMeter * @pixelsPerMeterHorizontal, topGlobalMeter * @pixelsPerMeterVertical ]

    @interaction_grids = undefined
    @regions = {} # json_id => { region: region, geometry: GeoJSON geometry, element: Paper element }
    @regionIds = [] # json IDs, used to sort @regions
    @overlayElements = {}
    @mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(state.indicator)

    childDiv = div.ownerDocument.createElement('div')
    childDiv.style.position = 'absolute'
    childDiv.style.top = 0
    childDiv.style.bottom = 0
    childDiv.style.left = 0
    childDiv.style.right = 0
    @div.appendChild(childDiv)
    @paper = new Paper(childDiv, {
      width: @tileSize.width,
      height: @tileSize.height,
      viewBox: "#{leftGlobalMeter} #{-topGlobalMeter} #{widthInMeters} #{heightInMeters}",
      scaleY: -1,
    })

    overlayDiv = div.ownerDocument.createElement('div')
    overlayDiv.style.position = 'absolute'
    overlayDiv.style.top = 0
    overlayDiv.style.bottom = 0
    overlayDiv.style.left = 0
    overlayDiv.style.right = 0
    @div.appendChild(overlayDiv)
    @overlayPaper = new Paper(overlayDiv, {
      width: @tileSize.width,
      height: @tileSize.height,
      viewBox: "#{leftGlobalMeter} #{-topGlobalMeter} #{widthInMeters} #{heightInMeters}",
      scaleY: -1,
    })

    this.requestData()

    event_class = this.id()
    $(document).on("opencensus:click.#{event_class}", (e, params) => this.onClick(params))
    $(document).on("opencensus:mousemove.#{event_class}", (e, params) => this.onMouseMove(params))
    $(document).on("opencensus:mouseout.#{event_class}", (e, params) => this.onMouseOut(params))
    state.onHoverRegionChanged(event_class, this.onHoverRegionChanged, this)
    state.onRegion1Changed(event_class, this.onRegion1Changed, this)
    state.onRegion2Changed(event_class, this.onRegion2Changed, this)
    state.onIndicatorChanged(event_class, this.onIndicatorChanged, this)

  requestData: () ->
    this.dataRequest = jQuery.ajax({
      url: this.url(),
      dataType: 'text',
      success: (data) => this.handleData(data)
    })

  drawPolygon: (paper, coordinates, style) ->
    strings = []

    moveto = Paper.Engine.PathInstructions.moveto
    lineto = Paper.Engine.PathInstructions.lineto
    close = Paper.Engine.PathInstructions.close
    finish = Paper.Engine.PathInstructions.finish

    for ring_coordinates in coordinates
      for globalMeter, i in ring_coordinates
        if i == 0
          strings.push(moveto)
        else
          strings.push(lineto)

        strings.push(globalMeter[0])
        strings.push(',')
        strings.push(globalMeter[1])

      strings.push(close)

    strings.push(finish)

    path = strings.join('')

    paper.path(path, style)

  drawGeometry: (paper, geometry, style) ->
    if typeof(geometry) == 'string'
      paper.path(geometry, style)
    else
      switch geometry.type
        when  'GeometryCollection'
          this.drawGeometry(paper, subgeometry, style) for subgeometry in geometry.geometries
        when 'MultiPolygon'
          this.drawPolygon(paper, subcoordinates, style) for subcoordinates in geometry.coordinates
        when 'Polygon'
          this.drawPolygon(paper, geometry.coordinates, style)

  getFillForRegion: (region) ->
    datum = region.getDatum(@mapIndicator)
    return undefined unless datum?.value?
    return undefined if datum.z <= @zoom
    bucket = @mapIndicator.bucketForValue(datum.value)
    bucket?.color

  handleData: (data) ->
    delete this.dataRequest

    data = parse_opencensus_geojson(data)

    for feature in data.features
      properties = feature.properties
      region = new Region(feature.id, properties.name, properties.parents, properties.statistics)
      region_store.add(region)
      @regions[region.id] = { region: region, geometry: feature.geometry }
      @regionIds.push(region.id)

    regions = @regions
    @regionIds.sort((a, b) -> -(regions[a].region.compareTo(regions[b].region)))

    @interaction_grids = new InteractionGridArray(@tileSize, data.utfgrids)

    this.drawRegions()

  drawRegions: () ->
    style = $.extend({}, polygon_style_base)

    for regionId in @regionIds
      regionData = @regions[regionId]
      fill = this.getFillForRegion(regionData.region)
      style.fill = fill || 'none'

      @paper.setStart()
      this.drawGeometry(@paper, regionData.geometry, style)
      element = @paper.setFinish()
      regionData.element = element

      element.hide() if !fill?

    this.onHoverRegionChanged(state.hover_region)
    this.onRegion1Changed(state.region)
    this.onRegion2Changed(state.region)

  restyle: () ->
    for regionId, regionData of @regions
      region = regionData.region
      element = regionData.element

      fill = this.getFillForRegion(region)
      if !fill?
        element.hide()
      else
        element.updateStyle({ fill: fill })
        element.show()

  id: () ->
    "MapTile-#{@zoom}-#{@coord.x}-#{@coord.y}"

  url: () ->
    base_url = globals.json_tile_url.replace('#{n}', ('' + ((@coord.x % 2) * 2 + (@coord.y % 2))))
    "#{base_url}/#{@zoom}/#{@coord.x}/#{@coord.y}.geojson"

  globalMeterToTilePixel: (globalMeter) ->
    [
      globalMeter[0] * @pixelsPerMeterHorizontal - @topLeftGlobalPixel[0],
      @topLeftGlobalPixel[1] - globalMeter[1] * @pixelsPerMeterVertical
    ]

  globalMeterToTilePixelOrUndefined: (globalMeter) ->
    ret = this.globalMeterToTilePixel(globalMeter)
    if ret[0] < 0 || ret[1] < 0 || ret[0] >= @tileSize.width || ret[1] >= @tileSize.height
      undefined
    else
      ret

  tilePixelToRegionList: (tilePixel) ->
    [ column, row ] = tilePixel

    return undefined unless @interaction_grids?
    @interaction_grids.pointToRegionList(column, row, @mapIndicator)

  onMouseMove: (point) ->
    globalMeter = point.world_xy
    tilePixel = this.globalMeterToTilePixelOrUndefined(globalMeter)

    if tilePixel?
      @lastMouseMoveWasOnThisTile = true

      hover_region = undefined

      region_list = this.tilePixelToRegionList(tilePixel) # may be undefined
      if region_list?
        for region in region_list
          if this.getFillForRegion(region)
            hover_region = region
            break

      state.setHoverRegion(hover_region) # Will only set if it's different
    else
      @lastMouseMoveWasOnThisTile = false

    true

  onMouseOut: () ->
    if @lastMouseMoveWasOnThisTile
      @lastMouseMoveWasOnThisTile = false
      state.setHoverRegion(undefined)

    true

  _setOverlayElement: (key, region) ->
    if @overlayElements[key]?
      @overlayElements[key].remove()
      @overlayElements[key] = undefined

    if region?
      geometry = @regions[region.id]?.geometry

      if geometry?
        @overlayPaper.setStart()
        # We can't use region.geometry.clone() because it's in a different document
        this.drawGeometry(@overlayPaper, geometry, overlay_polygon_styles[key])
        @overlayElements[key] = @overlayPaper.setFinish()

    @overlayElements.region2?.toFront()
    @overlayElements.region1?.toFront()

  onHoverRegionChanged: (hover_region) ->
    this._setOverlayElement('hover', hover_region)

  onRegion1Changed: (region1) ->
    this._setOverlayElement('region1', region1)

  onRegion2Changed: (region2) ->
    this._setOverlayElement('region2', region2)

  onIndicatorChanged: (indicator) ->
    @mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(indicator)
    this.restyle()

  onClick: (point) ->
    globalMeter = point.world_xy
    tilePixel = this.globalMeterToTilePixelOrUndefined(globalMeter)
    return if !tilePixel?

    region1 = undefined
    region2 = undefined
    region_list = this.tilePixelToRegionList(tilePixel)

    if region_list?
      for region in region_list
        # Compare populations because we don't want to select a ConsolidatedSubdivision
        # as parent of a Division when they're actually the same exact area.
        # This can introduce error if, say, a Subdivision and an ElectoralDistrict happen
        # to have the same population. Oh well.
        if region1? && region.getDatum(@mapIndicator)? && region.statistics?.pop?.value != region1.statistics?.pop?.value
          region2 = region
          break
        if this.getFillForRegion(region)
          region1 = region

    state.setRegionList(region_list)
    state.setRegion1(region1)
    state.setRegion2(region2)

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
