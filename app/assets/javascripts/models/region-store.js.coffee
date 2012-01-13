#= require app

class RegionStore
  constructor: (@region_types) ->
    @regions = {}

  add: (region) ->
    if regionData = @regions[region.id()]
      regionData.count += 1
    else @regions[region.id()] = { region: region, count: 1 }

  remove: (region_id) ->
    if regionData = @regions[region_id]
      regionData.count -= 1
      if regionData.count == 0
        @regions[region_id] = undefined

  get: (region_id) ->
    regionData = @regions[region_id]
    regionData && regionData.region || undefined

  # Returns all ancestors, as a list from Province down to (possibly) DisseminationArea
  getAncestors: (region_id) ->
    region = this.get(region_id)
    return [] if region is undefined

    all_parent_ids = {}

    parent_ids = region.parent_ids

    while parent_ids.length > 0
      old_parent_ids = parent_ids
      parent_ids = []

      for parent_id in old_parent_ids
        parent_region = this.get(parent_id)

        console.log(this)

        if parent_region
          [region_type, uid] = parent_id.split('-')
          all_parent_ids[region_type] = parent_id

          parent_ids.push(grandparent_id) for grandparent_id in parent_region.parent_ids

    console.log(all_parent_ids)
    ret = []
    for region_type in @region_types.region_types
      id = all_parent_ids[region_type.name]
      if id
        region = this.get(id)
        if region
          ret.push(region)

    ret

  getNearestRegionWithDatum: (region_id, year, indicator) ->
    region = this.get(region_id)
    return undefined if region is undefined
    return region if region.getDatum(year, indicator)
    return undefined if region.parent_ids is undefined

    best_candidate = undefined
    best_index = -1

    for parent_region_id in region.parent_ids
      parent_region = this.getNearestRegionWithDatum(parent_region_id, year, indicator)
      if parent_region
        type = parent_region.type
        index = @region_types.indexOfName(type)

        if index > best_index
          best_candidate = parent_region
          best_index = index

    return best_candidate

window.OpenCensus.models.RegionStore = RegionStore
