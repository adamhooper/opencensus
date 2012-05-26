#= require app
#= require globals

globals = window.OpenCensus.globals

window.OpenCensus.helpers.region_to_human_html = (region) ->
  region_type_human = globals.region_types.findByName(region.type)?.human_name()
  region_name = region.name

  # Change something like "Ottawa (Ontario part / partie en Ontario)" to "Ottawa"
  # (This is important because the part in parentheses is wrong.)
  if m = /(.*)\s*\(.*\/.*\)/.exec(region_name)
    region_name = m[1]

  $span = $('<span></span>')

  if region_type_human
    $region_type_span = $('<span class="region-type"></span>')
    $region_type_span.text(region_type_human)
    $span.append($region_type_span)

  if region_type_human? && region_name
    $span.append(' ')

  if region.name
    $region_name_span = $('<span class="region-name"></span>')
    $region_name_span.text(region_name)
    $span.append($region_name_span)

  return $span.html()
