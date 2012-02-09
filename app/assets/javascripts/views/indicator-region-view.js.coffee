#= require app
#= require globals
#= require state
#= require helpers/format-numbers

h = window.OpenCensus.helpers
globals = window.OpenCensus.globals
state = window.OpenCensus.state

class IndicatorRegionView
  constructor: (@indicator, @region) ->

  formatNumber: (n) ->
    f = h["format_#{@indicator.value_type}"]
    f(n)

  getMapIndicator: () ->
    globals.indicators.findMapIndicatorForTextIndicator(@indicator)

  getMapIndicatorRegionView: () ->
    new IndicatorRegionView(this.getMapIndicator(), @region)

  isCurrentIndicator: () ->
    state.indicator.equals(@indicator)

  getFragment: () ->
    $ret = $('<div class="statistic"><h4></h4></div>')
    $ret.find('h4').text(@indicator.name)

    datum = @region.getDatum(state.year, @indicator)

    if !datum || datum.value is undefined
      $ret.append("<span class=\"no-data\">no #{state.year.toString()} data</span>")
    else
      $value = $('<span class="value"></span>')
      $value.text(this.formatNumber(datum.value))
      $ret.append($value)

      if @indicator.unit
        $unit = $('<span class="unit"></span>')
        $unit.text(@indicator.unit)
        $ret.append(' ')
        $ret.append($unit)

      if datum.note
        $note = $('<span class="note"></span>')
        $note.text(datum.note)
        $ret.append($note)

    map_indicator = this.getMapIndicator()
    if map_indicator
      if this.isCurrentIndicator()
        map_indicator_region_view = this.getMapIndicatorRegionView()
        map_datum = @region.getDatum(state.year, map_indicator)
        map_value = map_datum && map_datum.value
        bucket = map_indicator.bucketForValue(map_value)
        if bucket isnt undefined
          fill = map_indicator.bucket_colors && map_indicator.bucket_colors[bucket] || globals.style.buckets[bucket]

          $p = $('<p class="is-current-indicator">On map: <span class="legend-color">&nbsp;</span> <span class="value"></span> <span class="unit"></span></p>')
          $p.find('span.legend-color').css('background', fill)
          $p.find('span.value').text(map_indicator_region_view.formatNumber(map_value))
          $p.find('span.unit').text(map_indicator.unit)
          $ret.append($p)
        else
          $ret.append('<p class="is-current-indicator">On map</p>')
      else
        $p = $('<p class="make-current-indicator"><a href="#">Show on map</a></p>')
        $p.find('a').on 'click', (e) =>
          e.preventDefault()
          e.stopPropagation()
          state.setIndicator(@indicator)
        $ret.append($p)

    $ret

window.OpenCensus.views.IndicatorRegionView = IndicatorRegionView
