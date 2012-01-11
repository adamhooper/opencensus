#= require app
#= require globals
#= require state
#= require views/indicator-region-view

globals = window.OpenCensus.globals
state = window.OpenCensus.state
IndicatorRegionView = window.OpenCensus.views.IndicatorRegionView

class RegionView
  constructor: (@region) ->

  listIndicators: () ->
    indicator = state.indicator
    indicators_with_ordering = ([pair.indicator, i] for pair, i in globals.indicators.findTextAndMapIndicators())
    indicators_with_ordering.sort (a, b) =>
      return -1 if a[0].equals(state.indicator)
      return 1 if b[0].equals(state.indicator)
      return a[1] - b[1]
    return (indicator_and_index[0] for indicator_and_index in indicators_with_ordering)

  getFragment: () ->
    $ret = $('<div class="region"><h2></h2><h3></h3></div>')
    $ret.find('h2').text(@region.name || '(unnamed)')
    $ret.find('h3').text(@region.type + ' ' + @region.uid)

    for indicator in this.listIndicators()
      indicatorRegionView = new IndicatorRegionView(indicator, @region)
      $fragment = indicatorRegionView.getFragment()
      $ret.append($fragment)

    $ret

window.OpenCensus.views.RegionView = RegionView
