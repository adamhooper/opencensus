#= require app
#= require state
#= require globals
#= require helpers/region-helpers
#= require image_path

state = window.OpenCensus.state
globals = window.OpenCensus.globals
h = window.OpenCensus.helpers

class RegionSelectorFromRegionList
  constructor: (@div, @n) ->
    @markerImageUrl = image_path("marker#{@n}.png")
    listenerKey = "region-selector-from-region-list-#{@n}"
    onRegionListChanged = "onRegionList#{@n}Changed"
    onRegionChanged = "onRegion#{@n}Changed"
    state[onRegionListChanged](listenerKey, () => this.refreshList())
    state[onRegionChanged](listenerKey, () => this.refreshSelected())

    this.refreshList()
    this.refreshSelected()

  refreshList: () ->
    $div = $(@div)
    $div.empty()

    region_list = state["region_list#{@n}"]
    setter = "setRegion#{@n}"
    selected_region = state["region#{@n}"]

    $form = $('<form><select></select></form>')
    $select = $form.children()

    populations = {}

    if region_list?
      for region in region_list
        if region.statistics?.pop?.value?
          # Ignore parent regions which are duplicates
          key = "#{region.statistics?.pop?.value || 0}"
          continue if populations[key]?
          populations[key] = true

        human_name = region.human_name()
        $option = $('<option></option>')
        $option.attr('value', region.id)
        $option.text(region.id)
        $option.attr('selected', 'selected') if region.id == selected_region?.id
        $select.append($option)

    if @n == 2
      $option = $('<option value="">(stop comparing)</option>')
      $option.attr('selected', 'selected') if !selected_region?.id
      $select.append($option)

    $div.append($form)
    $select.selectmenu({
      style: 'dropdown',
      width: $div.width(),
      maxHeight: 600,
      appendTo: $form,
      format: (region_id) ->
        region = globals.region_store.get(region_id)
        region && h.region_to_human_html(region) || region_id
    })

    $select.on 'change', () ->
      region_id = $select.val()
      region = globals.region_store.get(region_id)
      state[setter](region)

    if region_list?
      $div.append("<div class=\"prompt\">Drag <img src=\"#{@markerImageUrl}\" alt=\"marker\" width=\"9\" height=\"21\" /> to move</div>")
    else
      $div.append("<div class=\"prompt\">Click the map to drop a <img src=\"#{@markerImageUrl}\" alt=\"marker\" width=\"9\" height=\"21\" /></div>")

  refreshSelected: () ->
    $select = $(@div).find('select')

    region = state["region#{@n}"]
    other_region = state["region#{3 - @n}"]

    $select.selectmenu('value', region?.id)

    if region? && region.id == other_region?.id && @oldValue?
      otherSetter = "setRegion#{3 - @n}"
      otherRegion = globals.
      otherRegion = globals.region_store.get(@oldValue)
      state[otherSetter](otherRegion)

    @oldValue = region?.id

window.OpenCensus.views.RegionSelectorFromRegionList = RegionSelectorFromRegionList
