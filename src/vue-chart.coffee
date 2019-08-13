chart = null

commify = (s) -> s.toString().replace /// \B (?= (\d{3})+ (?!\d) ) ///g, ','

drawChart = (points) ->
  points = [1..90].map (i) ->
    t = moment("2019-08-01", 'YYYY-MM-D')
    t.add(i, 'days')
    return
      t: t.valueOf()
      y: Math.floor(Math.random() * 100000)

  if not chart
    config.data.datasets[0].data = points
    chart = new Chart document.getElementById('chart'), config
  else
    chart.data.datasets[0].data = points
    chart.update()

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
