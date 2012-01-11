#= require app
#= require state
#= require views/region-view

state = window.OpenCensus.state
RegionView = window.OpenCensus.views.RegionView

class TextView
  constructor: (@div) ->
    state.onRegionChanged('text-view', this.onRegionChanged, this)
    state.onIndicatorChanged('text-view', this.onIndicatorChanged, this)

  $div: () ->
    $(@div)

  onRegionChanged: (region) ->
    this.redraw()

  onIndicatorChanged: (indicator) ->
    this.redraw()

  redraw: () ->
    $div = this.$div()

    $div.empty()

    if !state.region
      $div.text('Click a region to see its statistics')
    else
      regionView = new RegionView(state.region)
      $div = regionView.getFragment()
      this.$div().append($div)

$ ->
  div = document.getElementById('info')
  new TextView(div)
