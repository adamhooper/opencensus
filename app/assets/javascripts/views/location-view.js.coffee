#= require app

class LocationView
  constructor: (@form) ->
    $(@form).on "submit", (e) ->
      e.preventDefault()

  onSubmit: (namespace, callback) ->
    $(@form).on("submit.#{namespace}", callback)

  getPointDescription: () ->
    $(@form).find('input[name=q]').val()

  setPointDescription: (point_description) ->
    $(@form).find('input[name=q]').val(point_description)

  setStatus: (severity, message=undefined) ->
    $status = $(@form).find('.status')
    $status[0].htmlClass = 'status' # remove other classes
    $status.addClass(severity) if severity?
    $status.text(message || '')
    if message?
      $status.show()
    else
      $status.hide()

window.OpenCensus.views.LocationView = LocationView
