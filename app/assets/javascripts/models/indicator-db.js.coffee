#= requie app
#= require models/indicator

Indicator = window.OpenCensus.models.Indicator

class IndicatorDb
  constructor: (properties_list) ->
    @indicators = (new Indicator(properties) for properties in properties_list)
    @indicators_by_name = {}
    (@indicators_by_name[indicator.name] = indicator) for indicator in @indicators

  findByName: (name) ->
    @indicators_by_name[name]

window.OpenCensus.models.IndicatorDb = IndicatorDb
