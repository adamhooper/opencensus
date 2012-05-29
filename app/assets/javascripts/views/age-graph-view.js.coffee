$ = jQuery

#= require app
#= require state
#= require views/graph-view

id_counter = 0

class AgeGraphView extends window.OpenCensus.views.GraphView
  constructor: (@region) ->
    super(@region)

  _getNextDivId: () ->
    "opencensus-age-graph-view-#{id_counter += 1}"

  getFragment: (width, height, background_color) ->
    agem = @region?.statistics?.agem
    agef = @region?.statistics?.agef

    return undefined if !agem?.value || !agef.value?

    # Prepend 0 so empty string becomes 0
    agem_ints = (parseInt("0#{a}", 10) for a in agem.value.split(/,/))
    agef_ints = (parseInt("0#{a}", 10) for a in agef.value.split(/,/))

    age_ints = (agem_ints[i] + agef_ints[i] for i in [0...agem_ints.length])
    categories = [ '0-4', '5-9', '10-14', '15-19', '20-24', '25-29', '30-34', '35-39', '40-44', '45-49', '50-54', '55-59', '60-64', '65-69', '70-74', '75-79', '80-84', '85+' ]

    $div = $('<div class="graph"><div class="inner"></div></div>')
    id = this._getNextDivId()
    $div.find('div.inner').attr('id', id)

    $('body').append($div) # so jqplot will work; we'll move it later
    $div.children().width(width)
    $div.children().height(height)

    values = ([ a, categories[i] ] for a, i in age_ints)

    # max 4 ticks
    max_int = 0
    for int in age_ints
      max_int = int if int > max_int
    interval = max_int * .3
    rounded_interval = interval.toFixed(0)
    if rounded_interval.length > 1
      rounded_interval = parseInt(rounded_interval.substring(0, 1) + rounded_interval.slice(1).replace(/\d/g, '0'), 10)
    else
      rounded_interval = parseInt(rounded_interval, 10)

    $.jqplot(id, [values], {
      highlighter: {
        show: true,
        tooltipAxes: 'x',
        tooltipLocation: 'e',
      },
      cursor: { show: false },
      seriesDefaults: {
        renderer: $.jqplot.BarRenderer,
        rendererOptions: {
          barDirection: 'horizontal',
          fillToZero: true,
          highlightMouseOver: true,
        },
        shadow: false,
      },
      axes: {
        yaxis: {
          renderer: $.jqplot.CategoryAxisRenderer,
          tickOptions: {
            showGridline: false,
          },
        },
        xaxis: {
          pad: 1.1,
          min: 0,
          tickInterval: rounded_interval
        },
      },
      grid: {
        background: background_color || 'white',
        shadow: false,
        borderWidth: 0,
      },
    })

    $div

window.OpenCensus.views.AgeGraphView = AgeGraphView
