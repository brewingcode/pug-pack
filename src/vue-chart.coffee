chart = null

commify = (s) -> s.toString().replace /// \B (?= (\d{3})+ (?!\d) ) ///g, ','

max = (arr) ->
  # each element has a .t property than can be coerced to a number
  arr.reduce (prev, curr) ->
    if +prev.t > +curr.t then prev else curr
  , {}

min = (arr) ->
  # each element has a .t property than can be coerced to a number
  arr.reduce (prev, curr) ->
    if +prev.t < +curr.t then prev else curr
  , {}

bucketize = (points, count, unit) ->
  return [] unless points.length > 0
  points.sort (a,b) -> +a.t - +b.t
  ref = points[0].t.clone().add(count, unit)
  buckets = [points.shift()]
  points.forEach (p) ->
    if p.t.isSameOrBefore(ref)
      buckets[buckets.length-1].y += p.y
    else
      buckets.push
        t: ref.clone()
        y: p.y
      ref.add(count, unit)
  return buckets

mostRecent = (points, count, unit) ->
  return [] unless points.length > 0
  latest = max(points)
  cutoff = latest.t.clone().subtract(count, unit)
  return points.filter (p) -> p.t.isSameOrAfter(cutoff)

widthCheck = ->
  meta = chart.getDatasetMeta(0).data
  sum = meta.reduce (acc, cur) ->
    acc + cur._model.width
  , 0
  if sum / meta.length < 1
    chart.options.scales.xAxes[0].barThickness = 3
    chart.update()

drawChart = _.debounce ->
  if typeof globalPoints[0]?.t is 'string'
    globalPoints.forEach (p) ->
      p.t = moment(p.t)
      p.y = +p.y

  data = globalPoints

  if app.$refs.mr.hasError or app.$refs.gb.hasError
    return

  if app.mostRecent and not app.$refs.mr.hasError
    m = app.mostRecent.match(app.regex)
    data = mostRecent(data, m[1], m[2])
  if app.groupBy and not app.$refs.gb.hasError
    m = app.groupBy.match(app.regex)
    data = bucketize(data, m[1], m[2])

  if not chart
    Chart.defaults.global.defaultFontSize = 16
    config.data.datasets[0].data = data
    chart = new Chart document.getElementById('chart'), config
  else
    delete chart.options.scales.xAxes[0].barThickness
    chart.data.datasets[0].data = data
    chart.update()

  widthCheck()

  app.stats =
    'Number of Dates': data.length
    'First Date': min(data).t.format('MMM D, YYYY h:mm:ssa')
    'Last Date': max(data).t.format('MMM D, YYYY h:mm:ssa')
, 300

globalPoints = []

config =
  type: 'bar'
  data:
    datasets: [{
      backgroundColor: '#FF6714'
    }]
  options:
    legend:
      display: false
    tooltips:
      callbacks:
        label: (tip, data) -> commify(tip.value)
    scales:
      xAxes: [{
        type: 'time'
      }]
      yAxes: [{
        ticks:
          callback: (v) -> commify(v)
      }]

app = new Vue
  el: '#app'
  vuetify: new Vuetify()

  data: ->
    groupBy: null
    mostRecent: null
    regex: /^\s*(\d+)\s*([a-z]+)\s*$/i
    stats: {}

  mounted: -> drawChart()

  watch:
    groupBy: -> drawChart()
    mostRecent: -> drawChart()

  methods:
    momentable: (v) ->
      return true if (not v) or v.match(/^\s*$/)
      m = v.match(app.regex)
      return "Unable to parse into '&lt;number> &lt;text>'" unless m
      a = moment()
      b = a.clone().add(m[1], m[2])
      return "Moment does not understand '#{m[1]}, #{m[2]}' for .add()" if +a is +b
      return true
