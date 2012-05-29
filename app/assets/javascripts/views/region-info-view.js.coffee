#= require app
#= require state
#= require helpers/format-numbers
#= require views/age-graph-view
#= require views/region-selector-from-region-list

$ = jQuery

h = window.OpenCensus.helpers
state = window.OpenCensus.state

AgeGraphView = window.OpenCensus.views.AgeGraphView
RegionSelectorFromRegionList = window.OpenCensus.views.RegionSelectorFromRegionList

class RegionInfoView
  constructor: (@div) ->
    $regionTh = $(@div).find('th.region:eq(0)')
    $regionTh.append('<div></div>')
    new RegionSelectorFromRegionList($regionTh.find('div'), 1)

    $regionCompareTh = $(@div).find('th.compare-region:eq(0)')
    $regionCompareTh.append('<div></div>')
    new RegionSelectorFromRegionList($regionCompareTh.find('div'), 2)

    this.refresh()
    state.onRegion1Changed 'region-info-view', () => this.refresh()
    state.onRegion2Changed 'region-info-view', () => this.refresh()

  refresh: () ->
    region = state.region1
    compareRegion = state.region2

    regionData = this.regionToData(region)
    compareRegionData = this.regionToData(compareRegion)

    visibleStatistics = this.visibleStatistics(regionData, compareRegionData)

    this.refreshVisibleRows(visibleStatistics)

    this.fillTableColumnData('region', regionData)
    this.fillTableColumnData('compare-region', compareRegionData)

    this.refreshBarWidths(regionData, compareRegionData)

    this.refreshUrls(region, compareRegion)
    this.refreshAgeGraphView(region, compareRegion)

  _fillThUrl: ($th, url) ->
    $th.empty()

    if url
      $a = $('<a target="_blank" title="opens in new window">Statistics Canada profile</a>')
      $a.attr('href', url)
      $th.append($a)

  refreshUrls: (region, compareRegion) ->
    $tr = $(@div).find('tbody.links tr')
    $th1 = $tr.find('td.region')
    $th2 = $tr.find('td.compare-region')

    this._fillThUrl($th1, region?.url())
    this._fillThUrl($th2, compareRegion?.url())

  _refreshOneAgeGraphView: ($div, region, background_color) ->
    $div.empty()
    chart = new AgeGraphView(region)
    fragment = chart.getFragment($div.width(), $div.height(), background_color)
    $div.append(fragment) if fragment?

  refreshAgeGraphView: (region, compareRegion) ->
    $tr = $(@div).find('tr.ages')
    this._refreshOneAgeGraphView($tr.find('td.region .age-chart'), region, '#ededee')
    this._refreshOneAgeGraphView($tr.find('td.compare-region .age-chart'), compareRegion, '#d8d7d5')

  formatValue: (key, value) ->
    switch key
      when 'pop' then h.format_integer(value)
      when 'dwe' then h.format_integer(value)
      when 'gro' then value.toFixed(1).charAt(0) == '-' && h.format_float(value, 1) || "+#{h.format_float(value, 1)}"
      when 'popdwe' then h.format_float(value, 1)
      when 'sexf' then h.format_float(value, 1)
      when 'sexm' then h.format_float(value, 1)
      else "#{value}"

  regionToData: (region) ->
    if !region?
      return {
        pop: undefined,
        gro: undefined,
        dwe: undefined,
        popdwe: undefined,
        sexm: undefined,
        sexf: undefined,
        ages: undefined,
      }

    ret = {
      pop: region.statistics?.pop
      gro: region.statistics?.gro,
      dwe: region.statistics?.dwe,
      popdwe: region.statistics?.popdwe,
      sexm: region.statistics?.sexm,
    }
    ret.sexf = ret.sexm? && { value: 100.0 - ret.sexm.value, note: ret.sexm.note } || undefined
    ret.ages = ret.sexm? && true || undefined # just to make the heading appear/disappear
    ret

  visibleStatistics: (region1Data, region2Data) ->
    ret = {}
    for key in [ 'pop', 'gro', 'dwe', 'popdwe', 'sexm', 'sexf', 'ages' ]
      ret[key] = (region1Data?[key]? || region2Data?[key]?)
    ret.regions = (region1Data? || region2Data?)
    ret

  refreshVisibleRows: (visibleRows) ->
    for key, visible of visibleRows
      $tbodies = $(@div).find("thead.#{key}, tbody.#{key}")
      if visible
        $tbodies.show()
      else
        $tbodies.hide()

  fillTableColumnData: (columnClass, data) ->
    $tds = $(@div).find("td.#{columnClass}")

    for key, datum of data
      $span = $tds.find("span.#{key}.value")
      $div = $tds.find("div.#{key}")

      if datum?.value?
        $span.text(this.formatValue(key, datum.value))
        $div.show()
      else
        $span.empty()
        $div.hide()

  refreshBarWidths: (region1Data, region2Data) ->
    for key, value1 of region1Data
      value2 = region2Data[key]

      value1 = value1?.value
      value2 = value2?.value

      $bar1 = $(@div).find("td.region div.#{key} span.bar")
      $bar2 = $(@div).find("td.compare-region div.#{key} span.bar")

      continue if $bar1.length < 1 && $bar2.length < 1

      $bars = [ $bar1, $bar2 ]

      if key == 'popdwe'
        widths = this._getIndicatorBarWidths(key, value1, value2)
      else
        widths = this._getComparedIndicatorBarWidths(key, value1, value2)

      for i in [ 0, 1 ]
        width = widths[i]
        $bar = $bars[i]

        continue if !width? || !$bar?

        if width
          $bar.width(width)
          $bar.show()
        else
          $bar.hide()

  _getIndicatorBarWidths: (key, value1, value2) ->
    maxWidth = 100
    unitWidth = {
      popdwe: 10,
    }[key]

    width1 = value1? && (value1 * unitWidth) || 0
    width1 = maxWidth if width1 > maxWidth

    width2 = value1? && (value2 * unitWidth) || 0
    width2 = maxWidth if width2 > maxWidth

    [ width1, width2 ]

  _getComparedIndicatorBarWidths: (key, value1, value2) ->
    maxWidth = 100
    unitWidth = {
      pop: 10,
      dwe: 20,
    }[key]
    maxMultiplier = maxWidth / unitWidth

    width1 = 0
    width2 = 0

    if (value2 && !value1) || (value1 && value2 && value1 > value2)
      swap = true
      [value1, value2] = [value2, value1]
    else
      swap = false

    if value1
      if value2
        if value1 * maxMultiplier >= value2
          width1 = unitWidth
          width2 = unitWidth * (value2 / value1)
        else
          width2 = maxWidth
          width1 = maxWidth * (value1 / value2)
      else
        width1 = unitWidth
        width2 = 0

    if swap
      [ width2, width1 ]
    else
      [ width1, width2 ]

$ ->
  $div = $('#opencensus-wrapper div.region-info')
  new RegionInfoView($div[0])
