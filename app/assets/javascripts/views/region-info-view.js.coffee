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
    new RegionSelectorFromRegionList($regionTh.find('div'), 'region1', 'region2')

    $regionCompareTh = $(@div).find('th.compare-region:eq(0)')
    $regionCompareTh.append('<div></div>')
    new RegionSelectorFromRegionList($regionCompareTh.find('div'), 'region2', 'region1')

    this.refresh()
    state.onRegion1Changed 'region-info-view', () => this.refresh()
    state.onRegion2Changed 'region-info-view', () => this.refresh()

  refresh: () ->
    region = state.region1
    compareRegion = state.region2

    regionData = this.regionToData(region)
    compareRegionData = this.regionToData(compareRegion)

    this.fillTableColumnData('region', regionData)
    this.fillTableColumnData('compare-region', compareRegionData)

    this.refreshAgeGraphView(region, compareRegion)

  refreshAgeGraphView: (region, compareRegion) ->
    $chart_div = $(@div).find('.age-chart')
    $chart_div.empty()

    chart = new AgeGraphView(region)
    fragment = chart.getFragment()
    $chart_div.append(fragment) if fragment?

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
      }

    ret = {
      pop: region.statistics?.pop
      gro: region.statistics?.gro,
      dwe: region.statistics?.dwe,
      popdwe: region.statistics?.popdwe,
      sexm: region.statistics?.sexm,
    }
    ret.sexf = ret.sexm? && { value: 100.0 - ret.sexm.value, note: ret.sexm.note } || undefined
    ret

  fillTableColumnData: (columnClass, data) ->
    $tds = $(@div).find("td.#{columnClass}")

    for key, datum of data
      $span = $tds.find("span.#{key}")
      $div = $tds.find("div.#{key}")
      $tbodies = $(@div).find("thead.#{key}, tbody.#{key}")

      if datum?.value?
        $span.text(this.formatValue(key, datum.value))
        $div.show()
        $tbodies.show()
      else
        $span.empty()
        $div.hide()
        $tbodies.hide()

$ ->
  $div = $('#opencensus-wrapper div.region-info')
  new RegionInfoView($div[0])
