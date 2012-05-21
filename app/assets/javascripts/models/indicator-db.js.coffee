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

  findTextAndMapIndicators: () ->
    return @text_and_map_indicators if @text_and_map_indicators

    raw = [
      [ 'Population', 'Population density' ],
      #[ 'Population growth', 'Population growth' ],
      [ 'Dwellings', 'Dwelling density' ],
      [ 'People per dwelling', 'People per dwelling' ]
    ]

    @text_and_map_indicators = ({ indicator: this.findByName(r[0]), map_indicator: this.findByName(r[1]) } for r in raw)

  findMapIndicatorForTextIndicator: (text_indicator) ->
    for pair in this.findTextAndMapIndicators()
      return pair.map_indicator if pair.indicator.equals(text_indicator)
    return undefined

  findTextIndicatorForMapIndicator: (map_indicator) ->
    for pair in this.findTextAndMapIndicators()
      return pair.indicator if pair.map_indicator.equals(map_indicator)
    return undefined

window.OpenCensus.models.IndicatorDb = IndicatorDb
