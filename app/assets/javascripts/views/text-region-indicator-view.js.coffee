#= require views/text-base-view

class TextRegionIndicatorView extends window.OpenCensus.views.TextBaseView
  render: ->
    html = this.simpleRender()

window.OpenCensus.views.TextRegionIndicatorView = TextRegionIndicatorView
