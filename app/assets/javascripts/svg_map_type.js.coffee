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

# Save some object creation
polygon_style_base = {
  stroke: globals.style.stroke,
  'stroke-width': globals.style['stroke-width'],
}
overlay_polygon_styles = {
  hover: $.extend({}, polygon_style_base, globals.hover_style),
  region1: $.extend({}, polygon_style_base, globals.selected_style1, {}),
  region2: $.extend({}, polygon_style_base, globals.selected_style2, {}),
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
    childDiv.style.top = "0px"
    childDiv.style.left = "0px"
    childDiv.style.width = "#{@tileSize.width}px"
    childDiv.style.height = "#{@tileSize.height}px"
    @div.appendChild(childDiv)
    @paper = new Paper(childDiv, {
      width: @tileSize.width,
      height: @tileSize.height,
      viewBox: "#{leftGlobalMeter} #{-topGlobalMeter} #{widthInMeters} #{heightInMeters}",
      scaleY: -1,
    })

    overlayDiv = div.ownerDocument.createElement('div')
    overlayDiv.style.position = 'absolute'
    overlayDiv.style.top = "0px"
    overlayDiv.style.left = "0px"
    childDiv.style.width = "#{@tileSize.width}px"
    childDiv.style.height = "#{@tileSize.height}px"
    @div.appendChild(overlayDiv)
    @overlayPaper = new Paper(overlayDiv, {
      width: @tileSize.width,
      height: @tileSize.height,
      viewBox: "#{leftGlobalMeter} #{-topGlobalMeter} #{widthInMeters} #{heightInMeters}",
      scaleY: -1,
    })

    this.requestData()

    event_class = this.id()
    $(document).on("opencensus:mousemove.#{event_class}", (e, params) => this.onMouseMove(params))
    $(document).on("opencensus:mouseout.#{event_class}", (e, params) => this.onMouseOut(params))
    state.onHoverRegionChanged(event_class, this.onHoverRegionChanged, this)
    state.onRegion1Changed(event_class, this.onRegion1Changed, this)
    state.onRegion2Changed(event_class, this.onRegion2Changed, this)
    state.onIndicatorChanged(event_class, this.onIndicatorChanged, this)
    state.onPoint1Changed(event_class, this.onPoint1Changed, this)
    state.onPoint2Changed(event_class, this.onPoint2Changed, this)

    this._refreshOpacity()

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

  getRegionShouldBeVisible: (region) ->
    datum = region.getDatum(@mapIndicator)
    return false if !datum?.value?
    return false if datum.z <= @zoom
    return @mapIndicator.bucketForValue(datum.value) && true || false

  getFillForRegion: (region) ->
    datum = region.getDatum(@mapIndicator)
    return undefined unless datum?.value?
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
    this.maybeUpdateRegionLists()

  _maybeUpdateRegionListN: (n) ->
    point = state["point#{n}"]
    return if !point?
    
    globalMeter = point.world_xy
    tilePixel = this.globalMeterToTilePixelOrUndefined(globalMeter)
    return if !tilePixel?

    region_list = this.tilePixelToRegionList(tilePixel)
    return if !region_list?

    current_region_list = state["region_list#{n}"]
    if region_list.length > (current_region_list?.length || 0)
      state["setRegionList#{n}"](region_list)

  maybeUpdateRegionLists: () ->
    this._maybeUpdateRegionListN(1)
    this._maybeUpdateRegionListN(2)

  drawRegions: () ->
    style = $.extend({}, polygon_style_base)

    for regionId in @regionIds
      regionData = @regions[regionId]
      visible = this.getRegionShouldBeVisible(regionData.region)
      fill = visible && this.getFillForRegion(regionData.region)
      style.fill = fill || 'none'

      @paper.setStart()
      this.drawGeometry(@paper, regionData.geometry, style)
      element = @paper.setFinish()
      regionData.element = element

      element.hide() if !fill

    this.onHoverRegionChanged(state.hover_region)
    this.onRegion1Changed(state.region1)
    this.onRegion2Changed(state.region2)

  restyle: () ->
    for regionId, regionData of @regions
      region = regionData.region
      element = regionData.element

      visible = this.getRegionShouldBeVisible(regionData.region)
      fill = visible && this.getFillForRegion(region)
      if !fill
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

  _refreshOpacity: () ->
    hovering = state.hover_region?

    if !@hovering? || hovering != @hovering
      opacity = globals.style[hovering && 'opacity_faded' || 'opacity_full']

      $childDiv = $(@div).children(':eq(0)')
      $childDiv.stop(true)
      $childDiv.animate({ opacity: opacity }, { duration: 'fast' })

    @hovering = hovering

  onMouseMove: (point) ->
    globalMeter = point.world_xy
    tilePixel = this.globalMeterToTilePixelOrUndefined(globalMeter)

    if tilePixel?
      @lastMouseMoveWasOnThisTile = true

      hover_region = undefined

      region_list = this.tilePixelToRegionList(tilePixel) # may be undefined
      if region_list?
        for region in region_list
          if region.getDatum(@mapIndicator)?.value?
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
        style = $.extend({ fill: this.getFillForRegion(region) }, overlay_polygon_styles[key])
        this.drawGeometry(@overlayPaper, geometry, style)
        @overlayElements[key] = @overlayPaper.setFinish()

    @overlayElements.region2?.toFront()
    @overlayElements.region1?.toFront()

  onHoverRegionChanged: (hover_region) ->
    this._refreshOpacity()
    this._setOverlayElement('hover', hover_region)

  onRegion1Changed: (region1) ->
    this._setOverlayElement('region1', region1)

  onRegion2Changed: (region2) ->
    this._setOverlayElement('region2', region2)

  onIndicatorChanged: (indicator) ->
    @mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(indicator)
    this.restyle()

  _onPointNChanged: (n, point) ->
    region = undefined
    region_list = undefined

    if point?
      globalMeter = point.world_xy
      tilePixel = this.globalMeterToTilePixelOrUndefined(globalMeter)
      return if !tilePixel? # This point is on a different tile; ignore it

      region_list = this.tilePixelToRegionList(tilePixel)

    new_region = undefined

    if region_list?
      for region in region_list
        ## If somebody's already in comparison mode, keep him/her there.
        ##
        ## Compare populations because we don't want to select a ConsolidatedSubdivision
        ## as parent of a Division when they're actually the same exact area.
        ## This can introduce error if, say, a Subdivision and an ElectoralDistrict happen
        ## to have the same population. Oh well.
        #if region1? && state.region2? && region.getDatum(@mapIndicator)? && region.statistics?.pop?.value != region1.statistics?.pop?.value
        #  region2 = region
        #  break
        if region.getDatum(@mapIndicator)?.value?
          new_region = region
          break

    state["setRegionList#{n}"](region_list)
    state["setRegion#{n}"](new_region)

  onPoint1Changed: (point1) ->
    this._onPointNChanged(1, point1)

  onPoint2Changed: (point2) ->
    this._onPointNChanged(2, point2)

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
