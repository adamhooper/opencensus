#= require app

$ ->
  div = document.getElementById('info')

  $(document).on 'opencensus:regionhoverin', (e, region) ->
    $(div).text("#{region.id} ... #{region.properties.name}")
