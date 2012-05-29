#= require app
#= require globals
#= require state

globals = window.OpenCensus.globals
state = window.OpenCensus.state

class IndicatorSelectorView
  constructor: (@ul) ->
    $ul = $(@ul)
    $ul.hide()

    $select = $('<select></select>')
    bodies = {}

    $ul.find('li').each () ->
      $a = $(this).find('a')
      key = $a.attr('href').split(/#/)[1]
      text = $a.text()
      $option = $('<option></option>')
      $option.attr('value', key)
      $option.text(text)
      $select.append($option)

    $select.val(state.indicator.key)

    $form = $('<form></form>')
    $form.append($select)

    $ul.after($form)

    $select.selectmenu({
      style: 'dropdown',
      width: '13em',
      maxHeight: 500,
      appendTo: $form
    })
    this._refreshValue()

    $select.on 'change', (e) =>
      key = $select.val()
      indicator = globals.indicators.findByKey(key)
      state.setIndicator(indicator)
      this._refreshValue()

    $form.on 'selectmenuclose', (e) =>
      this._refreshValue()

    state.onIndicatorChanged 'indicator-selector-view', () =>
      $select.val(state.indicator.key)
      this._refreshValue()

  _refreshValue: () ->
    $form = $(@ul).next()
    $span = $form.find('span.ui-selectmenu-status')
    if !$span.find('.prompt').length
      $span.append('<span class="prompt">Click to change</span>')

$ ->
  $ul = $('#opencensus-wrapper ul.indicators')
  new IndicatorSelectorView($ul[0])
