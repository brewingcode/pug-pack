chart = null

commify = (s) -> s.toString().replace /// \B (?= (\d{3})+ (?!\d) ) ///g, ','

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
        t: ref
        y: p.y
      ref.add(count, unit)
  return buckets

drawChart = ->
  if not chart
    config.data.datasets[0].data = points
    chart = new Chart document.getElementById('chart'), config
  else
    chart.data.datasets[0].data = points
    chart.update()

points = [1..90].map (i) ->
  t = moment("2019-08-01", 'YYYY-MM-D')
  t.add(i, 'days')
  return
    t: t
    y: Math.floor(Math.random() * 100000)

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
    onClick: -> drawChart()

app = new Vue
  el: '#app'
  vuetify: new Vuetify()
  data: ->
    isLoading: false
  mounted: ->
    drawChart()
