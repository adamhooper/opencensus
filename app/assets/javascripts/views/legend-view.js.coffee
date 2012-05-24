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

    all_bucket_values = []
    for bucket in mapIndicator.buckets()
      all_bucket_values.push(bucket.min) if bucket.min?
      all_bucket_values.push(bucket.max) if bucket.max?

    format_number = h.get_formatter_for_numbers(all_bucket_values)

    $ul = $('<ul class="swatches"></ul>')
    for bucket, i in mapIndicator.buckets()
      fill = mapIndicator.bucket_colors[i]

      $li = $('<li><span class="swatch">&nbsp;</span><span class="range">up to</span> <span class="number"></span></li>')
      $li.find('.swatch').css('background', fill)

      if bucket.max?
        number = bucket.max
      else
        number = bucket.min
        $li.find('.range').text('over')

      $li.find('.number').text(format_number(number))

      $ul.append($li)

    $div.append($ul)

$ ->
  $div = $('#opencensus-wrapper>div.legend')
  new LegendView($div[0])
