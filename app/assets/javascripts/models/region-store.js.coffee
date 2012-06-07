#= require app

$ = jQuery

class RegionStore
  constructor: (@region_types) ->
    @regions = {}

  _changeCount: (region_id, diff) ->
    if regionData = @regions[region_id]
      regionData.count += diff

      for parent_id in regionData.region.parent_ids
        this._changeCount(parent_id, diff) # Don't care about duplicates

  incrementCount: (region_id) ->
    this._changeCount(region_id, 1)

  decrementCount: (region_id) ->
    this._changeCount(region_id, -1)

  add: (region) ->
    if regionData = @regions[region.id]
      regionData.count += 1
    else @regions[region.id] = { region: region, count: 1 }

  remove: (region_id) ->
    if regionData = @regions[region_id]
      regionData.count -= 1
      if regionData.count == 0
        @regions[region_id] = undefined

  get: (region_id) ->
    regionData = @regions[region_id]
    regionData && regionData.region || undefined

  getRegionListFromChildRegionIds: (region_ids) ->
    return undefined if !region_ids?

    all_ids = {}

    next_wave = region_ids
    while next_wave.length > 0
      this_wave = next_wave
      next_wave = []

      for region_id in this_wave
        continue if all_ids[region_id]?

        region = this.get(region_id)
        continue if !region?

        all_ids[region_id] = true

        for parent_id in region.parent_ids
          next_wave.push(parent_id) # don't mind duplicates

    ret = (this.get(region_id) for region_id, _ of all_ids)

    ret.sort((a, b) -> a.compareTo(b))

    ret

window.OpenCensus.models.RegionStore = RegionStore
