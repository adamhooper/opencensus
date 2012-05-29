$ = jQuery

#= require app

class Indicator
  constructor: (attributes) ->
    @key = attributes.key
    @name = attributes.name
    @value_type = attributes.value_type
    @unit = attributes.unit
    @description = attributes.description
    @buckets = $.parseJSON(attributes.buckets)

  bucketForValue: (value) ->
    return undefined if !value?
    for bucket in @buckets
      return bucket if !bucket.max? || bucket.max >= value

window.OpenCensus.models.Indicator = Indicator
