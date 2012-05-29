#= require app
#= require globals
#= require state
#= require helpers/bucket-helpers

$ = jQuery

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

    $ul = $('<ul class="swatches"></ul>')
    for bucket in mapIndicator.buckets
      label = h.bucket_to_label(bucket)

      $li = $('<li><span class="swatch">&nbsp;</span><span class="label"></span></li>')
      $li.find('.swatch').css('background', bucket.color)

      $li.find('.label').text(label)

      $ul.append($li)

    $div.append($ul)

$ ->
  $div = $('#opencensus-wrapper>div.legend')
  new LegendView($div[0])
