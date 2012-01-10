#= require app

window.OpenCensus.helpers.format_float = (n, decimals = 2) ->
  s = n.toFixed(decimals)
  if decimals > 3
    while /[.,]\d{4}/.test(s)
      s = s.replace(/([.,])(\d{3})(\d)/, '$1$2,$3')
  while /\d{4}/.test(s)
    s = s.replace(/(\d)(\d{3})([\.,$])/, '$1,$2$3')
  s

window.OpenCensus.helpers.format_int = (n) ->
  window.OpenCensus.helpers.format_float(n, 0)

window.OpenCensus.helpers.format_percent = (n, decimals = 2) ->
  "#{window.OpenCensus.helpers.format_float(n * 100, decimals)}%"
