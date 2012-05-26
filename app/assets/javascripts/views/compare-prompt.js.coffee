#= require app
#= require state

state = window.OpenCensus.state

class ComparePrompt
  constructor: (@a) ->
    $a = $(@a)
    $div = $a.parent().parent()
    @div = $div[0]

    @widthCollapsed = $div.find('th:eq(0)').outerWidth()

    state.onRegion2Changed('compare-prompt', () => this.delayedRefresh())
    @expanded = (state.region2?)
    this.refresh()

    $a.on 'click', (e) =>
      e.preventDefault()
      this.toggle()

  delayedRefresh: () ->
    @delayedRefreshTimeout ||= window.setTimeout(() =>
      this.refresh()
      @delayedRefreshTimeout = undefined
    , 50)

  refresh: () ->
    shouldBeExpanded = state.region2?
    $div = $(@div)
    if shouldBeExpanded && !@expanded
      $div.stop(true)
      $div.animate({ 'margin-left': -@widthCollapsed })
    if !shouldBeExpanded && @expanded
      $div.stop(true)
      $div.animate({ 'margin-left': 0 })
    @expanded = shouldBeExpanded

  toggle: () ->
    if state.region2?
      state.setRegion2(undefined)
    else if state.region1? && state.region_list?
      region2 = undefined

      # Default to the smallest region larger than this one
      region1_pop = state.region1.statistics?.pop?.value || 0
      for region in state.region_list
        continue if region.equals(state.region1)
        continue if (region.statistics?.pop?.value || 0) <= region1_pop

        region2 = region
        break

      # If that fails, pick the smallest one possible
      if !region2?
        for region in state.region_list
          continue if region.equals(state.region1)
          region2 = region
          break

      state.setRegion2(region2) # may--theoretically--be undefined

$ ->
  $a = $('#opencensus-wrapper div.region-info div.compare-prompt a')
  new ComparePrompt($a[0])
