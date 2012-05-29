#= require app
#= require state

$ = jQuery

startup = ($opencensus_div) ->
  $form = $opencensus_div.find('form.location')
  $form.addClass('startup')

  end = () ->
    $form.off('.startup')
    $form.find('a.skip').off('.startup')
    $form.fadeOut () ->
      $form.removeClass('startup')
      $form.fadeIn()
      $form = undefined

  $form.on 'submit.startup', (e) ->
    e.preventDefault()
    return false if $.trim($(e.target).closest('form').find('input.text').val()) == ''
    end()

  $form.find('a.skip').on 'click.startup', (e) ->
    e.preventDefault()
    end()

$ ->
  $div = $('#opencensus-wrapper')
  startup($div)
