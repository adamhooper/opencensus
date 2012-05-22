#= require app
#= require state
#= require views/graph-view

id_counter = 0

class AgeGraphView extends window.OpenCensus.views.GraphView
  constructor: (@region) ->
    super(@region, 'Age distribution')

  _getNextDivId: () ->
    "opencensus-age-graph-view-#{id_counter += 1}"

  getFragment: () ->
    agem = @region?.statistics?['Population by age, male']
    agef = @region?.statistics?['Population by age, female']

    return undefined if !agem?.value || !agef.value?

    # Prepend 0 so empty string becomes 0
    agem_ints = (parseInt("0#{a}", 10) for a in agem.value.split(/,/))
    agef_ints = (parseInt("0#{a}", 10) for a in agef.value.split(/,/))

    age_ints = (agem_ints[i] + agef_ints[i] for i in [0...agem_ints.length])
    categories = [ '0-4', '5-9', '10-14', '15-19', '20-24', '25-29', '30-34', '35-39', '40-44', '45-49', '50-54', '55-59', '60-64', '65-69', '70-74', '75-79', '80-84', '85+' ]

    $div = $('<div class="graph"><h2></h2><div class="inner"></div></div>')
    $div.find('h2').text(@title)
    id = this._getNextDivId()
    $div.find('div.inner').attr('id', id)

    $('body').append($div) # so jqplot will work; we'll move it later
    $div.width(300)

    values = ([ a, i ] for a, i in age_ints)
    ticks = ([i, c] for c, i in categories)

    $.jqplot(id, [values], {
      #highlighter: { show: true, sizeAdjust: 12 },
      #cursor: { show: false },
      seriesDefaults: {
        renderer: $.jqplot.BarRenderer,
        rendererOptions: {
          barDirection: 'horizontal',
          barPadding: 2,
          barMargin: 0,
          barWidth: 10,
          groups: 1,
        },
        shadow: false,
      },
      axes: {
        yaxis: {
          renderer: $.jqplot.CategoryAxisRenderer,
          ticks: ticks,
        },
      },
    })

    $div

window.OpenCensus.views.AgeGraphView = AgeGraphView
