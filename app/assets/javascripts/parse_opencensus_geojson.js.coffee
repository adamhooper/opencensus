#= require paper

$ = jQuery

GEOJSON_REGEXP = /\{"crs".*?\}\},.*"features":\[(.*)\],"utfgrids":(.*)\}/
FEATURE_REGEXP = /"id":"([^"]*)","properties":(.*),"geometry":(.*)/

geometry_json_to_string = (geometry_json) ->
  moveto = Paper.Engine.PathInstructions.moveto
  lineto = Paper.Engine.PathInstructions.lineto
  close = Paper.Engine.PathInstructions.close
  finish = Paper.Engine.PathInstructions.finish

  arr = []

  polygon_regexp = /\[\[\[([^\[].*?)\]\]\]/g
  while (polygon_match = polygon_regexp.exec(geometry_json))?
    arr.push(moveto)
    arr.push(polygon_match[1].replace(/\]\],\[\[/g, close + moveto).replace(/\],\[/g, lineto))
    arr.push(close)

  arr.push(finish)

  arr.join('')

# Returns a JSON-like object, except every "geometry" is an SVG-like string
# This makes some huge assumptions about the data OpenCensus' backend provides:
#
# * There are no extraneous spaces in the JSON
# * The first element is the "crs", and it ends with '}}'
# * The second-last element is "features", and all features have:
# ** "type":"Feature" as a first element
# ** "id" second, a string that can be used as an XML ID
# ** "properties" third, and nothing in there contains a key '"geometry"'
#     or "utfgrids"
# ** "geometry" fourth and last, and all geometries are of type
#    GeometryCollection, MultiPolygon and Polygon.
# * The last element is "utfgrids", an array of UTFGrid elements
#
# Why use this instead of parseJSON? Because IE is so incredibly slow at
# parsing JSON. This method lets IE pass verbose "geometry" values as strings,
# without ever needing to parse them.
window.parse_opencensus_geojson = (text) ->
  result = GEOJSON_REGEXP.exec(text)
  return undefined if !result?

  features_json = result[1]
  utfgrids_json = result[2]

  features = []

  feature_jsons = features_json.split(/\{"type":"Feature"/)
  for feature_json in feature_jsons
    feature_match = FEATURE_REGEXP.exec(feature_json)
    continue if !feature_match?
    id = feature_match[1]
    properties_json = feature_match[2]
    geometry_json = feature_match[3]

    properties = $.parseJSON(properties_json)
    geometry = geometry_json_to_string(geometry_json)

    features.push({ id: id, properties: properties, geometry: geometry })

  utfgrids = $.parseJSON(utfgrids_json)

  { features: features, utfgrids: utfgrids }
