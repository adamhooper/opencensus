#= require views/base-view

class TextBaseView extends window.oc.views.BaseView
  escape: (s) ->
    $x = $('<div></div>')
    $x.text(s)
    $x.innerHtml()

  render: ->
    this.simpleRender()

  refresh: ->
    html = this.render()

  simpleRender: ->
    htmlTemplate = this.getHtmlTemplate()
    htmlTemplate.replaceAll(/\#{(.*)}/, escape(@model.get($1)))

  getHtmlTemplate: ->
    '''
      <div class="base">
        <p>This is an error. Define getHtmlTemplate().</p>
      </div>
    '''

window.oc.views.TextBaseView = TextBaseView
