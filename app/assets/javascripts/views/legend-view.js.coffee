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

    $others = $('<div class="others">or show:<ul></ul></div>')
    $ul = $others.find('ul')
    for obj in globals.indicators.findTextAndMapIndicators()
      continue if obj.map_indicator.name == mapIndicator.name
      $li = $('<li><a href="#"></a></li>')
      $li.find('a').text(obj.indicator.name)
      $li.data('indicator', obj.indicator)
      $li.on 'click', (e) ->
        e.preventDefault()
        indicator = $(e.target).closest('li').data('indicator')
        state.setIndicator(indicator)
      $ul.append($li)
    $div.append($others)

    $ul = $('<ul class="swatches"></ul>')
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
