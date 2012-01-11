#= require app
#= require globals
#= require state
#= require helpers/format-numbers
#= require views/indicator-view

h = window.OpenCensus.helpers
globals = window.OpenCensus.globals
state = window.OpenCensus.state
IndicatorView = window.OpenCensus.views.IndicatorView

class TextView
  constructor: (@div) ->
    state.onRegionChanged('text-view', this.onRegionChanged, this)

  $div: () ->
    $(@div)

  onRegionChanged: (region) ->
    this.setRegion(region)

  usefulIndicators: () ->
    raw = [
      [ 'Population', 'Population density' ],
      [ 'Dwellings', 'Dwelling density' ],
      [ 'People per dwelling', 'People per dwelling' ]
    ]

    { indicator: globals.indicators.findByName(r[0]), map_indicator: globals.indicators.findByName(r[1]) } for r in raw

  setRegion: (region) ->
    if (!region)
      this.clear()
      return

    $div = this.$div()

    name = region.name || '(unnamed)'
    $h2 = $('<h2></h2>').text(name)
    $h3 = $('<h3></h3>').text(region.type)

    $div.empty()
    $div.append($h2)
    $div.append($h3)

    this.setStatistics(region.statistics)

  setStatistics: (statistics) ->
    return unless statistics

    thisYear = statistics[state.year.toString()]
    return unless thisYear

    $div = this.$div()

    for indicatorData in this.usefulIndicators()
      indicator = indicatorData.indicator
      mapIndicator = indicatorData.map_indicator

      value = thisYear[indicator.name]
      mapValue = thisYear[mapIndicator.name]

      continue unless value && mapValue

      value_string = undefined
      console.log
      if indicator.value_type == 'float'
        value_string = h.format_float(value.value)
      else if indicator.value_type == 'integer'
        value_string = h.format_integer(value.value)

      $h4 = $('<h4></h4>').text("#{indicator.name}: #{value_string}")
      $div.append($h4)

      if value.note
        $note = $('<p class="note"></p>').text("Note on this data: #{value.note}")
        $div.append($note)

      if indicator.name == state.indicator.name || mapIndicator.name == state.indicator.name
        $div.append('<p>This is shown on the map.</p>')
        this.setLegend(mapIndicator)

  setLegend: (indicator) ->
    indicatorView = new IndicatorView(indicator)
    $fragment = indicatorView.getLegendFragment()
    this.$div().append($fragment)

  clear: () ->
    this.$div().text('Click on a region to see info...')

$ ->
  div = document.getElementById('info')
  new TextView(div)
