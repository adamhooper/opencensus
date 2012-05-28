#= require app
#= require state
#= require helpers/format-numbers
#= require views/age-graph-view
#= require views/region-selector-from-region-list

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
      $a = $('<a target="_blank" title="opens in new window">StatsCan Profile</a>')
      $a.attr('href', url)
      $th.append($a)

  refreshUrls: (region, compareRegion) ->
    $tr = $(@div).find('tbody.links tr')
    $th1 = $tr.find('td.region')
    $th2 = $tr.find('td.compare-region')

    this._fillThUrl($th1, region?.url())
    this._fillThUrl($th2, compareRegion?.url())

  _refreshOneAgeGraphView: ($div, region) ->
    $div.empty()
    chart = new AgeGraphView(region)
    fragment = chart.getFragment($div.width())
    $div.append(fragment) if fragment?

  refreshAgeGraphView: (region, compareRegion) ->
    $tr = $(@div).find('tr.ages')
    this._refreshOneAgeGraphView($tr.find('td.region .age-chart'), region)
    this._refreshOneAgeGraphView($tr.find('td.compare-region .age-chart'), compareRegion)

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
      this.refreshIndicatorBarWidths(key, value1?.value || 0, value2?.value || 0)

  refreshIndicatorBarWidths: (key, value1, value2) ->
    width1 = 0
    width2 = 0

    if (value2 && !value1) || (value1 && value2 && value1 > value2)
      swap = true
      [value1, value2] = [value2, value1]
    else
      swap = false

    if value1
      if value2
        if value1 * 10 >= value2
          width1 = 10
          width2 = 10 * (value2 / value1)
        else
          width2 = 100
          width1 = 100 * (value1 / value2)
      else
        width1 = 10
        width2 = 0

    if swap
      [width1, width2] = [width2, width1]

    $bar1 = $(@div).find("td.region span.bar.#{key}")
    $bar2 = $(@div).find("td.compare-region span.bar.#{key}")

    if width1
      $bar1.show()
      $bar1.width(width1)
    else
      $bar1.hide()

    if width2
      $bar2.show()
      $bar2.width(width2)
    else
      $bar2.hide()

$ ->
  $div = $('#opencensus-wrapper div.region-info')
  new RegionInfoView($div[0])
