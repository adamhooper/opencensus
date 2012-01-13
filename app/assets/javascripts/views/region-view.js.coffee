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

  getParentsFragment: () ->
    ancestors = globals.region_store.getAncestors(@region.id())
    return undefined if ancestors.length == 0

    $ul = $('<ul class="region-ancestors"></ul>')
    for region in ancestors
      $li = $('<li></li>')

      $type = $('<div class="region-type"></div>')
      $type.text(region.type)
      $li.append($type)

      if region.name
        $name = $('<div class="region-name"></div>')
        $name.text(region.name)
        $li.append($name)

      datum = region.getDatum(state.year, state.indicator)
      if datum
        view = new IndicatorRegionView(state.indicator, region)
        $value = $('<div class="value"></div>')
        $value.text(view.formatNumber(datum.value))
        $li.append($value)

      $ul.append($li)
    $ul

  getFragment: () ->
    $ret = $('<div class="region"><div class="region-type"></div><h2></h2></div>')
    $ret.find('.region-type').text(@region.type)
    $ret.find('h2').text(@region.name || '(unnamed)')

    for indicator in this.listIndicators()
      indicatorRegionView = new IndicatorRegionView(indicator, @region)
      $fragment = indicatorRegionView.getFragment()
      $ret.append($fragment)

    $parents = this.getParentsFragment()
    $ret.prepend($parents) if $parents

    $ret

window.OpenCensus.views.RegionView = RegionView
