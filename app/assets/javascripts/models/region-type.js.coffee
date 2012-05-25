#= require app

human_names = {
  DisseminationBlock: 'Block',
  DisseminationArea: 'Area',
  Tract: 'Tract',
  Subdivision: 'Subdivision'
  ConsolidatedSubdivision: 'C-Subdivision',
  Division: 'Division',
  MetropolitanArea: 'Metropolitan area',
  ElectoralDistrict: 'Electoral district',
  EconomicRegion: 'Economic region',
}

class RegionType
  constructor: (properties) ->
    @name = properties.name
    @description = properties.description

  human_name: () ->
    human_names[@name]

window.OpenCensus.models.RegionType = RegionType
