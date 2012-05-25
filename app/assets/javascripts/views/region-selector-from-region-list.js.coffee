#= require app
#= require state
#= require globals
#= require helpers/region-helpers

state = window.OpenCensus.state
globals = window.OpenCensus.globals
h = window.OpenCensus.helpers

class RegionSelectorFromRegionList
  constructor: (@div, @key) ->
    listenerKey = "region-selector-from-region-list-#{@key}"
    onChange = "on#{@key.charAt(0).toUpperCase()}#{@key.slice(1)}Changed"
    state.onRegionListChanged(listenerKey, () => this.refreshList())
    state[onChange](listenerKey, () => this.refreshSelected())

    this.refreshList()
    this.refreshSelected()

  refreshList: () ->
    $div = $(@div)
    $div.empty()

    return if !state.region_list?

    setter = "set#{@key.charAt(0).toUpperCase()}#{@key.slice(1)}"

    $form = $('<form><select></select></form>')
    $select = $form.children()

    selected_region = state[@key]

    for region in state.region_list
      human_name = region.human_name()
      $option = $('<option></option>')
      $option.attr('value', region.id)
      $option.text(region.id)
      $option.attr('selected', 'selected') if region.id == selected_region?.id
      $select.append($option)

    $div.append($form)
    $select.selectmenu({
      style: 'dropdown',
      width: '100%',
      maxHeight: 600,
      appendTo: $form,
      format: (region_id) -> h.region_to_human_html(globals.region_store.get(region_id))
    })

    $select.on 'change', () ->
      region_id = $select.val()
      region = globals.region_store.get(region_id)
      state[setter](region)

  refreshSelected: () ->
    $select = $(@div).find('select')

    region = state[@key]

    $select.selectmenu('value', region?.id)

window.OpenCensus.views.RegionSelectorFromRegionList = RegionSelectorFromRegionList
