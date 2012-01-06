#= require app
#= require globals
#= require state

globals = window.OpenCensus.globals
state = window.OpenCensus.state

class InfoDiv
  constructor: (@div) ->
    $(document).on 'opencensus:regionhoverin', (e, region_id, properties) =>
      this.onRegionHoverIn(region_id, properties)
    $(document).on 'opencensus:regionhoverout', (e) =>
      this.onRegionHoverOut()

  $div: () ->
    $('#info')

  onRegionHoverIn: (region_id, properties) ->
    this.setProperties(properties)

  onRegionHoverOut: () ->
    this.clear()

  usefulIndicators: () ->
    raw = [
      [ 'Population', 'Population density' ],
      [ 'Dwellings', 'Dwelling density' ],
      [ 'People per dwelling', 'People per dwelling' ]
    ]

    { indicator: globals.indicators.findByName(r[0]), map_indicator: globals.indicators.findByName(r[1]) } for r in raw

  setProperties: (properties) ->
    $div = this.$div()

    name = properties.name || '(unnamed)'
    $h2 = $('<h2></h2>').text(name)
    $h3 = $('<h3></h3>').text(properties.type)

    $div.empty()
    $div.append($h2)
    $div.append($h3)

    this.setStatistics(properties.statistics)

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

      $h4 = $('<h4></h4>').text("#{indicator.name}: #{value.value}")
      $div.append($h4)

      if value.note
        $note = $('<p class="note"></p>').text("Note on this data: #{value.note}")
        $div.append($note)

      if indicator.name == state.indicator.name || mapIndicator.name == state.indicator.name
        $div.append('<p>This is shown on the map. Here is the legend:</p>')
        this.setLegend(mapIndicator)

  setLegend: (indicator) ->
    $div = this.$div()

    $ul = $('<ul class="legend"></ul>')
    for bucket, i in indicator.buckets()
      $li = $('<li></li>')
      $span = $('<span>&nbsp;</span>').css({
        background: globals.style.buckets[i],
        border: '1px solid black',
      })
      $li.append($span)
      $li.append("#{bucket.min} to #{bucket.max} #{indicator.unit}")
      $ul.append($li)

    $div.append($ul)

  clear: () ->
    this.$div().text('Hover over a region to see info...')

$ ->
  new InfoDiv()
