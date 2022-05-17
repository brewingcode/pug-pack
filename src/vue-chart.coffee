chart = null

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

sum = (arr) ->
  x = 0
  x += a for a in arr
  return x

bucketize = (points, count, unit, method) ->
  return [] unless points.length > 0
  points.sort (a,b) -> +a.t - +b.t

  ref = points[0].t.clone()
  buckets = []
  i = 0

  while ref.isSameOrBefore(points[points.length-1].t)
    while i < points.length
      p = points[i]
      if p.t.isBefore(ref)
        # inside the current ref
        buckets[buckets.length-1].vals.push p.y
        i++
      else
        # exceeded the current ref
        break

    # start a new bucket (or the first one)
    buckets.push {t:ref.clone(), vals:[]}
    ref = ref.add(count, unit)

    # if we're out of points
    if i > points.length - 1
      break

  # if we're out of of buckets, catch any remaining points in the last one
  if i <= points.length - 1
    buckets[buckets.length-1].vals.push ...points.slice(i).map (p) -> p.y

  for b in buckets
    if method is 'sum' or not method
      b.y = sum b.vals
    else if method is 'avg'
      b.y = (sum(b.vals) / b.vals.length).toFixed(3)
    else if method is 'max'
      b.y = Math.max b.vals...
    else if method is 'min'
      b.y = Math.min b.vals...
    else
      b.y = 0
  return buckets

mostRecent = (points, count, unit) ->
  return [] unless points.length > 0
  latest = max(points)
  cutoff = latest.t.clone().subtract(count, unit)
  return points.filter (p) -> p.t.isSameOrAfter(cutoff)

widthCheck = ->
  meta = chart.getDatasetMeta(0).data
  if sum(meta.map (m) -> m._model.width) / meta.length < 1
    chart.options.scales.xAxes[0].barThickness = 3
    chart.update()

drawChart = _.debounce ->
  if typeof globalPoints[0]?.t is 'string'
    globalPoints.forEach (p) ->
      p.t = moment.utc(p.t)
      p.y = +p.y

  if app.$refs.mr.hasError or app.$refs.gb.hasError
    return

  app.points = if app.useRandomData then randomPoints else globalPoints

  if app.mostRecent and not app.$refs.mr.hasError
    m = app.mostRecent.match(app.regex)
    app.points = mostRecent(app.points, m[1], m[2])
  if app.groupBy and not app.$refs.gb.hasError
    m = app.groupBy.match(app.regex)
    app.points = bucketize(app.points, m[1], m[2], m[3])

  if not chart
    Chart.defaults.global.defaultFontSize = 16
    config.data.datasets[0].data = app.points
    chart = new Chart document.getElementById('chart'), config
  else
    delete chart.options.scales.xAxes[0].barThickness
    chart.data.datasets[0].data = app.points
    chart.update()

  widthCheck()

  if app.points.length > 0
    yValues = app.points.map (p) -> p.y

    #console.log 'app.points:', app.points.length, ', yValues: ', yValues, ', sum:', sum
    app.stats =
      'Number of Points': app.points.length
      'First Date': min(app.points).t.format()
      'Last Date': max(app.points).t.format()

    app.moreStats =
      'Average': (sum(yValues) / app.points.length).toFixed(3)
      'Min': commify Math.min(yValues...)
      'Max': commify Math.max(yValues...)
      'Duration': dhms( ( max(app.points).t - min(app.points).t ) / 1000 )
  else
    app.stats = null
    app.moreStats = null
, 300

randomPoints = [1..500].map (i) ->
  t = moment("2019-08-01", 'YYYY-MM-D')
  t.add(Math.random()*i, 'days')
  return
    t: t
    y: Math.floor(Math.random() * 100000)
randomPoints.sort (a,b) -> +a.t - +b.t

globalPoints = []
initialGroupBy = null

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
        title: (tips, data) ->
          tip = tips[0]
          config.data.datasets[tip.datasetIndex].data[tip.index].t.format()
        label: (tip, data) -> commify(tip.value)
    scales:
      xAxes: [{
        type: 'time'
        time:
          displayFormats:
            hour: 'HH:mm:ss'
      }]
      yAxes: [{
        ticks:
          callback: (v) -> commify(v)
      }]

app = new Vue
  el: '#app'
  template:'#app'
  vuetify: new Vuetify()

  data: ->
    groupBy: null
    mostRecent: null
    useRandomData: false
    regex: /^\s*(\d+)\s*([a-z]+)\s*(\w+)?$/i
    points: [1] # this will get correctly set on first drawChart()
    stats: null
    moreStats: null
    tooltip: false
    copyResult: ''
    pasteError:
      show: false
      text: ''

  computed:
    dataSize: -> filesize(JSON.stringify(@points).length)

  mounted: ->
    bindInputQueryParam '#mr', null, null, (v) => @mostRecent = v
    bindInputQueryParam '#gb', null, null, (v) => @groupBy = v
    if initialGroupBy
      @groupBy = initialGroupBy
    else
      drawChart()

  watch:
    groupBy: -> drawChart()
    mostRecent: -> drawChart()
    useRandomData: -> drawChart()

  methods:
    momentable: (v) ->
      return true if (not v) or v.match(/^\s*$/)
      m = v.match(app.regex)
      return "Unable to parse into '<number> <text>'" unless m
      a = moment()
      b = a.clone().add(m[1], m[2])
      return "Moment does not understand '#{m[1]}, #{m[2]}' for .add()" if +a is +b
      return true

    pbcopy: ->
      navigator.clipboard.writeText(JSON.stringify(@points)).then =>
        @tip('copied')
      , =>
        @tip('copy failed')

    tip: (text) ->
      @copyResult = text
      @tooltip = true
      setTimeout (=> @tooltip = false), 1000

    pbpaste: ->
      navigator.clipboard.readText().then (text) =>
        try
          globalPoints = JSON.parse(text)
          throw new Error "JSON must be an array" unless globalPoints.length > 0
          throw new Error "Array objects must have a `t` and `y` property" if globalPoints.find (p) -> not p.t or not p.y
          drawChart()
        catch e
          @pasteError.show = true
          @pasteError.text = e.message

