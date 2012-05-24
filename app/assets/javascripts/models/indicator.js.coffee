#= require app

class Indicator
  constructor: (attributes) ->
    @key = attributes.key
    @name = attributes.name
    @value_type = attributes.value_type
    @unit = attributes.unit
    @description = attributes.description
    @buckets_string = attributes.buckets
    @bucket_colors = attributes.bucket_colors?.split(/,/)

  buckets: ->
    return @memoized_buckets if @memoized_buckets

    ret = []
    for s in @buckets_string.split(/\s*,\s*/)
      min = undefined
      max = undefined

      if m = /less than ([-\d\.]*)/.exec(s)
        max = parseFloat(m[1])
      else if m = /more than ([-\d\.]*)/.exec(s)
        min = parseFloat(m[1])
      else
        bucket = s.split(' to ')
        min = parseFloat(bucket[0])
        max = parseFloat(bucket[1])

      ret.push({ min: min, max: max })

    @memoized_buckets = ret

  bucketForValue: (value) ->
    return undefined if !value?
    for bucket, i in this.buckets()
      return i if value <= bucket.max
    this.buckets().length - 1

  equals: (other) ->
    @name == other.name

window.OpenCensus.models.Indicator = Indicator
