#= require app
#= require helpers/format-numbers.js.coffee

window.OpenCensus.helpers.bucket_to_label = (bucket) ->
  return bucket.label if bucket.label?
  return 'more' if !bucket.max?

  formatter = window.OpenCensus.helpers.get_formatter_for_numbers(bucket.max)
  return "up to #{formatter(bucket.max)}"
