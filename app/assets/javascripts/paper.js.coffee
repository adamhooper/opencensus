getEngineName = () ->
  engineName = (window.SVGAngle || document.implementation.hasFeature("http://www.w3.org/TR/SVG11/feature#BasicStructure", "1.1")) && "SVG" || "VML"
  if engineName == 'VML'
    d = document.createElement('div')
    d.innerHtml = '<v:shape adj="1"/>'
    b = d.firstChild
    b.style.behavior = 'url(#default#VML)'
    if !(b && typeof(b.adj) == 'object')
      engineName = ''
  engineName

class PaperElementSet
  constructor: (@elements) ->

  updateStyle: (attrs) ->
    (element.updateStyle(attrs) for element in @elements)

  remove: () ->
    (element.remove() for element in @elements)

  setVisibility: (visibility) ->
    (element.setVisibility(visibility) for element in @elements)

  show: () ->
    this.setVisibility(true)

  hide: () ->
    this.setVisibility(false)

  toFront: () ->
    (element.toFront() for element in @elements)

class PaperElement
  constructor: (@engine, @engineElement) ->

  updateStyle: (attrs) ->
    @engine.updateElementStyle(@engineElement, attrs)

  remove: () ->
    @engine.removeElement(@engineElement)

  setVisibility: (visibility) ->
    @engine.setElementVisibility(@engineElement, visibility)

  show: () ->
    this.setVisibility(true)

  hide: () ->
    this.setVisibility(false)

  toFront: () ->
    @engine.elementToFront(@engineElement)

class SvgEngine
  constructor: (div, attrs) ->
    @svg = this._createEngineElement('svg')
    this.updateElementStyle(@svg, {
      width: attrs.width || '100%',
      height: attrs.height || '100%',
      version: '1.1',
      xmlns: 'http://www.w3.org/2000/svg',
    })
    @svg.style.cssText = 'overflow:hidden;position:relative'
    div.appendChild(@svg)

  _createEngineElement: (tagName) ->
    engineElement = document.createElementNS('http://www.w3.org/2000/svg', tagName)
    engineElement.style?.webkitTapHighlightColor = 'rgba(0,0,0,0)'
    engineElement

  path: (pathString, attrs) ->
    engineElement = this._createEngineElement('path')
    this.updateElementStyle(engineElement, attrs)
    engineElement.setAttribute('stroke', attrs.stroke || '#000000')
    engineElement.setAttribute('stroke-width', attrs['stroke-width'] || '1')
    engineElement.setAttribute('fill', attrs.fill || 'none')
    engineElement.setAttribute('d', pathString)
    @svg.appendChild(engineElement)

    new PaperElement(this, engineElement)

  updateElementStyle: (engineElement, attrs) ->
    for key, val of attrs
      engineElement.setAttribute(key, val)

  removeElement: (engineElement) ->
    engineElement.parentNode?.removeChild(engineElement)

  setElementVisibility: (engineElement, visibility) ->
    if visibility
      engineElement.style.display = 'none'
    else
      engineElement.style.display = ''

  elementToFront: (engineElement) ->
    engineElement.parentNode.appendChild(engineElement)

  remove: () ->
    @svg.parentNode && @svg.parentNode.removeChild(@svg)
    @svg = undefined

class Paper
  constructor: (div, attrs) ->
    @engine = new Paper.Engine(div, attrs)

  setStart: () ->
    @setElements = []

  path: (pathString, attrs) ->
    element = @engine.path(pathString, attrs)
    @setElements.push(element) if @setElements?
    element

  setFinish: () ->
    element = new PaperElementSet(@setElements)
    @setElements = undefined
    element

  remove: () ->
    @engine.remove()
    @engine = undefined

if getEngineName() == 'SVG'
  Paper.Engine = SvgEngine

window.Paper = Paper
