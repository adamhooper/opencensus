#= require app
#= require globals
#= require helpers/format-numbers

h = window.OpenCensus.helpers
globals = window.OpenCensus.globals

class IndicatorView
  constructor: (@indicator) ->

  getLegendFragment: () ->
    $ret = $('<div class="legend"></div>')

    format_number = h["format_#{@indicator.value_type}"]

    $ret.append('<h5>Legend</h5>')

    $ul = $('<ul></ul>')
    for bucket, i in @indicator.buckets()
      fill = globals.style.buckets[i]

      $li = $('<li><span class="sample">&nbsp;</span><span class="min"></span> to <span class="max"></span></li>')
      $li.find('.sample').css('background', fill)
      $li.find('.min').text(format_number(bucket.min))
      $li.find('.max').text(format_number(bucket.max))

      $ul.append($li)

    $ret.append($ul)

    if @indicator.unit
      $p = $('<p class="unit">in <span class="unit"></span></p>')
      $p.find('span.unit').text(@indicator.unit)
      $ret.append($p)

    $ret

window.OpenCensus.views.IndicatorView = IndicatorView
