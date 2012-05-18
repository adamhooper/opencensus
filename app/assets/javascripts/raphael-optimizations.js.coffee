#= require raphael

Raphael.fn.optimized_path = (pathString, attrs) ->
  out = Raphael._engine.optimized_path(this, pathString, attrs)
  @__set__ && @__set__.push(out)

Element = Raphael.el.constructor

if Raphael.svg
  Raphael._engine.optimized_path = (svg, pathString, attrs) ->
    stroke = attrs.stroke || '#000000'
    strokeWidth = attrs['stroke-width'] || 1
    fill = attrs.fill || 'none'

    el = Raphael._g.doc.createElementNS('http://www.w3.org/2000/svg', 'path')
    el.style && (el.style.webkitTapHighlightColor = "rgba(0,0,0,0)"; el.style.display = '')
    el.setAttribute('d', pathString)
    el.setAttribute('stroke', stroke)
    el.setAttribute('stroke-width', strokeWidth)
    el.setAttribute('fill', fill)
    svg.canvas && svg.canvas.appendChild(el)

    p = new Element(el, svg)
    p.type = 'path'
    p.attrs = {}
    return p

  Raphael.optimized_path_creation_strings = { moveto: 'M', lineto: 'L', close: 'Z' }
else if Raphael.vml
  createNode = undefined
  if document.namespaces.rvml
    createNode = (tagName) ->
      document.createElement("<rvml:#{tagName} class=\"rvml\">")
  else
    createNode = (tagName) ->
      document.createElement("<#{tagName} xmlns=\"urn:schemas-microsoft.com:vml\" class=\"rvml\">")

  Raphael._engine.optimized_path = (vml, pathString, attrs) ->
    el = createNode('shape')
    el.style.cssText = 'position:absolute;left:0;top:0;width:1px;height:1px'
    el.coordsize = '256 256'
    el.coordorigin = '0 0'

    p = new Element(el, vml)
    p.type = 'path'
    p.path = []
    p.Path = ''
    p.attrs = {}
    for key in attrs
      p.attrs[key] = attrs[key] if attrs.hasOwnProperty(key)

    vml.canvas.appendChild(el)

  Raphael.optimized_path_creation_strings = { moveto: 'm', lineto: 'l', close: 'x' }
