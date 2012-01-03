#= require app

class Indicator
  constructor: (properties) ->
    @name = properties.name
    @unit = properties.unit
    @description = properties.description
    @buckets_string = properties.buckets

  buckets: ->
    return @memoized_buckets if @memoized_buckets

    ret = []
    for s in @buckets_string.split(';')
      bucket = s.split(' to ')
      ret.push({ min: parseFloat(bucket[0]), max: parseFloat(bucket[bucket.length - 1]) })

    @memoized_buckets = ret

  bucketForValue: (value) ->
    for bucket, i in this.buckets()
      return i if value <= bucket.max
    undefined

window.OpenCensus.models.Indicator = Indicator
