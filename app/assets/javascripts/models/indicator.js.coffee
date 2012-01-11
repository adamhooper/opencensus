#= require app

class Indicator
  constructor: (attributes) ->
    @name = attributes.name
    @value_type = attributes.value_type
    @unit = attributes.unit
    @description = attributes.description
    @buckets_string = attributes.buckets

  buckets: ->
    return @memoized_buckets if @memoized_buckets

    ret = []
    for s in @buckets_string.split(';')
      bucket = s.split(' to ')
      ret.push({ min: parseFloat(bucket[0]), max: parseFloat(bucket[bucket.length - 1]) })

    @memoized_buckets = ret

  bucketForValue: (value) ->
    return undefined if value is undefined
    for bucket, i in this.buckets()
      return i if value <= bucket.max
    undefined

  equals: (other) ->
    @name == other.name

window.OpenCensus.models.Indicator = Indicator
