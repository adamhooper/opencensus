#= require app
#= require globals
#= require state

globals = window.OpenCensus.globals
state = window.OpenCensus.state

class IndicatorSelectorView
  constructor: (@ul) ->
    state.onIndicatorChanged('indicator-selector-view', this.onIndicatorChanged, this)
    this.addListener()
    this.refresh()

  addListener: () ->
    $(@ul).on 'click', 'li', (e) ->
      e.preventDefault()

      $a = $(e.target).closest('li').children('a')
      href = $a.attr('href')
      key = href.split(/#/)[1]

      indicator = globals.indicators.findByKey(key)
      state.setIndicator(indicator)

  onIndicatorChanged: (indicator) ->
    this.refresh()

  refresh: () ->
    indicator = state.indicator

    $ul = $(@ul)
    $ul.find('li').removeClass('selected')
    $li = $ul.find("li.#{indicator.key}")
    $li.addClass('selected')

$ ->
  $ul = $('#opencensus-wrapper ul.indicators')
  new IndicatorSelectorView($ul[0])
