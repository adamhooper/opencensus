#= requie app
#= require models/indicator

$ = jQuery

Indicator = window.OpenCensus.models.Indicator

class IndicatorDb
  constructor: (properties_list) ->
    @indicators = (new Indicator(properties) for properties in properties_list)
    @indicators_by_key = {}
    @indicators_by_name = {}
    (@indicators_by_key[indicator.key] = indicator) for indicator in @indicators

  findByKey: (key) ->
    @indicators_by_key[key]

  findMapIndicatorForTextIndicator: (text_indicator) ->
    key = {
      pop: 'popdens',
      gro: 'gro',
      popdwe: 'popdwe',
      agemedian: 'agemedian',
      sexm: 'sexm',
    }[text_indicator.key]

    key? && @indicators_by_key[key] || undefined

window.OpenCensus.models.IndicatorDb = IndicatorDb
