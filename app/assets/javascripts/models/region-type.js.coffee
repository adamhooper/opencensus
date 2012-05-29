$ = jQuery

#= require app

URL_FORMAT = 'http://www12.statcan.gc.ca/census-recensement/2011/dp-pd/prof/details/page.cfm?Lang=E&Geo1=$type1&Code1=$uid1&Geo2=$type2&Code2=$uid2&Data=Count&SearchText=Canada&SearchType=Begins&SearchPR=01&B1=All&Custom=&TABID=1'
TRACT_URL_FORMAT = 'http://www12.statcan.gc.ca/census-recensement/2011/dp-pd/prof/search-recherche/frm_res_geocode.cfm?Lang=E&SearchText=$uid1'

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

url_types = {
  Tract: 'CT',
  Subdivision: 'CSD',
  Division: 'CD',
  MetropolitanArea: 'CMA',
  ElectoralDistrict: 'FED',
  EconomicRegion: 'ER',
  Province: 'PR',
  Country: 'PR'
}

class RegionType
  constructor: (properties) ->
    @name = properties.name
    @description = properties.description

  human_name: () ->
    human_names[@name]

  url_for_region: (region) ->
    return undefined if !url_types[@name]?

    replacements = {
      type1: url_types[@name],
      type2: url_types.Country,
      uid1: region.uid,
      uid2: '01',
    }

    url_format = URL_FORMAT

    if @name == 'Tract'
      url_format = TRACT_URL_FORMAT
    if @name == 'Country'
      replacements.uid1 = '01'

    url_format.replace(/\$\w+/g, (m) -> replacements[m.slice(1)])

window.OpenCensus.models.RegionType = RegionType
