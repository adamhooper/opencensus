#= require app

class RegionStore
  constructor: () ->
    @regions = {}

  add: (region) ->
    if regionData = @regions[region.id()]
      regionData.count += 1
    else @regions[region.id()] = { region: region, count: 1 }

  remove: (region) ->
    if regionData = @regions[region.id()]
      regionData.count -= 1
      if regionData.count == 0
        @regions[region.id()] = undefined

  getById: (region_id) ->
    regionData = @regions[region_id]
    regionData && regionData.region || undefined

window.OpenCensus.models.RegionStore = RegionStore
