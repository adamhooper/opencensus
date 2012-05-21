#= require app
#= require globals
#= require state
#= require helpers/format-numbers

globals = window.OpenCensus.globals
state = window.OpenCensus.state
h = window.OpenCensus.helpers

class LegendView
  constructor: (@div) ->
    state.onIndicatorChanged('legend-view', this.onIndicatorChanged, this)
    this.refresh()

  onIndicatorChanged: (indicator) ->
    this.refresh()

  refresh: () ->
    indicator = state.indicator
    mapIndicator = globals.indicators.findMapIndicatorForTextIndicator(indicator)

    $div = $(@div)
    $div.empty()

    format_number = h["format_#{mapIndicator.value_type}"]

    $heading = $('<h2></h2>')
    $heading.text(indicator.name)
    $div.append($heading)

    if mapIndicator.unit
      $unit = $('<div class="unit">shown in <strong></strong></div>')
      $unit.find('strong').text(mapIndicator.unit)
      $div.append($unit)

    $ul = $('<ul></ul>')
    for bucket, i in mapIndicator.buckets()
      fill = mapIndicator.bucket_colors[i]

      $li = $('<li><span class="sample">&nbsp;</span><span class="min"></span><span class="range"> to </span><span class="max"></span></li>')
      $li.find('.sample').css('background', fill)
      if bucket.min?
        $li.find('.min').text(format_number(bucket.min))
      if bucket.max?
        $li.find('.max').text(format_number(bucket.max))
      if !bucket.min?
        $li.find('.min').remove()
        $li.find('.range').remove()
        $li.find('.max').prepend('up to ')
      if !bucket.max?
        $li.find('.max').remove()
        $li.find('.range').remove()
        $li.find('.min').prepend('over ')

      $ul.append($li)

    $div.append($ul)

$ ->
  div = document.getElementById('legend')
  new LegendView(div)
