#= require state

$ = jQuery

state = window.OpenCensus.state

class Geocoder
  constructor: (caller) ->
    @geocoder = new google.maps.Geocoder()
    @caller = caller

  geocode: (search) ->
    request = {
      address: search,
      region: 'CA'
    }

    @geocoder.geocode request, (results, status) =>
      if status == google.maps.GeocoderStatus.OK
        @caller.onGeocoderSuccess(results[0])
      else if status == google.maps.GeocoderStatus.ZERO_RESULTS
        @caller.onGeocoderZeroResults(search)
      else if status == google.maps.GeocoderStatus.OVER_QUERY_LIMIT
        @caller.onGeocoderOverQueryLimit()
      else if status == google.maps.GeocoderStatus.REQUEST_DENIED
        @caller.onGeocoderRequestDenied()
      else if status == google.maps.GeocoderStatus.INVALID_REQUEST
        @caller.onGeocoderInvalidRequest(search)
      else if status == google.maps.GeocoderStatus.UNKNOWN_ERROR
        @caller.onGeocoderUnknownError(search)
      else if status == google.maps.GeocoderStatus.ERROR
        @caller.onGeocoderError(search)

class SearchView
  constructor: (@form) ->
    @geocoder = new Geocoder(this)

    $(@form).on 'submit', (e) =>
      e.preventDefault()
      this.onSubmit()

  onSubmit: () ->
    q = $(@form).find('input[name=q]').val() || ''

    q = q.replace(/^\s+|\s+$/g, '') # trim

    if q.length > 0
      @geocoder.geocode(q)
      this.startSpinning()
    else
      this.clear()

  startSpinning: () ->
    @form.disabled = 'disabled'

  stopSpinning: () ->
    @form.disabled = ''

  flashMessage: (message, html_class) ->
    $form = $(@form)

    $div = $('<div><p></p></div>')
    $div.addClass(html_class)
    $div.find('p').text(message)

    $div.css({ opacity: 0 })
    $form.append($div)
    $div.animate({ opacity: 1 }).delay(3000).animate({ opacity: 0 }, () -> $(this).remove())

  flashWarning: (message) ->
    this.flashMessage(message, 'warning')

  flashNotice: (message) ->
    this.flashMessage(message, 'notice')

  flashError: (message) ->
    $form = $(@form)

    $div = $('<div class="error"><p></p></div>')
    $div.find('p').text(message)

    completeFunction = () ->
      $a = $('<a href="#">dismiss</a>')
      $a.on 'click', () ->
        $div.animate({ opacity: 0 }, 'fast', () -> $(this).remove())
      $div.append($a)

    $div.css({ opacity: 0 })
    $form.append($div)
    $div.animate({ opacity: 1 }, 'fast')

  onGeocoderSuccess: (result) ->
    formatted_address = result.formatted_address
    location = result.geometry.location
    viewport = result.geometry.viewport

    position = {
      latitude: location.lat(),
      longitude: location.lng(),
      bounds: [
        viewport.getSouthWest().lng(),
        viewport.getNorthEast().lat(),
        viewport.getNorthEast().lng(),
        viewport.getSouthWest().lat()
      ]
    }

    state.setPosition(position)

    this.flashNotice("Zooming to: #{formatted_address}")
    this.stopSpinning()
    this.clear()

  onGeocoderZeroResults: (search) ->
    this.flashWarning("No places found for: #{search}")
    this.stopSpinning()

  onGeocoderError: () ->
    this.flashError("We couldn't search because your computer couldn't contact Google")
    this.stopSpinning()

  onGeocoderUnknownError: () ->
    this.flashError("Google's servers failed to process your search. Please try again.")
    this.stopSpinning()

  onGeocoderOverQueryLimit: () ->
    this.flashError('This web page has searched Google for places too many times too recently.')
    this.stopSpinning()

  onGeocoderRequestDenied: () ->
    this.flashError('This web page is not allowed to use Google to search for places.')
    this.stopSpinning()

  onGeocoderInvalidRequest: (search) ->
    this.flashError('This web page mishandled your search.')
    this.stopSpinning()

  clear: () ->
    $(@form).find('input[name=q]').val('')

$ ->
  form = document.getElementById('search')
  new SearchView(form)
