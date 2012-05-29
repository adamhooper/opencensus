#= require app
#= require state

startup = ($opencensus_div) ->
  $form = $opencensus_div.find('form.location')
  $form.addClass('startup')

  end = () ->
    $form.fadeOut () ->
      $form.removeClass('startup')
      $form.fadeIn()

  $form.one 'submit', (e) ->
    e.preventDefault()
    end()

  $form.find('a.skip').on 'click', (e) ->
    e.preventDefault()
    end()

$ ->
  $div = $('#opencensus-wrapper')
  startup($div)
