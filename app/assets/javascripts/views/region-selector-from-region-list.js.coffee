#= require app
#= require state
#= require globals

state = window.OpenCensus.state
globals = window.OpenCensus.globals

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
      $option.text(human_name)
      $option.attr('selected', 'selected') if region.id == selected_region?.id
      $select.append($option)

    $div.append($form)
    $select.selectmenu({
      style: 'dropdown',
      width: '100%',
      maxHeight: 500,
      appendTo: $form
    })

    $select.on 'change', () ->
      region_id = $select.val()
      region = globals.region_store.get(region_id)
      state[setter](region)

  refreshSelected: () ->
    $select = $(@div).find('select')
    $select.val(state[@key]?.id)
    $select.trigger('change')

window.OpenCensus.views.RegionSelectorFromRegionList = RegionSelectorFromRegionList
