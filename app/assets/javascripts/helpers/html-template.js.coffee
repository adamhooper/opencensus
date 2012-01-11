#= require app

class HtmlTemplate
  constructor: (@html) ->

  $htmlFragment: () ->
    @htmlFragment_cache ||= $(@html)

  generateHtmlFragment: (params = {}) ->
    $ret = this.$htmlFragment().clone()
    for key, attrs of params
      $elems = $ret.find(".#{key}")

      text = attrs.delete('text')
      $elems.text(text) if text

      html = attrs.delete('html')
      $elems.html(html) if html

      $elems.attr(attrs)

window.OpenCensus.helpers.HtmlTemplate = HtmlTemplate
