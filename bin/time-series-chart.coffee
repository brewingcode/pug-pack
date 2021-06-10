#!/usr/bin/env coffee

fs = require 'fs'
argv = require('minimist') process.argv.slice(2),
  boolean: ['h', 'help']
moment = require 'moment'
tmp = require 'tmp'
{ execSync } = require 'child_process'
getStdin = require 'get-stdin'

moment.suppressDeprecationWarnings = true

do ->
  if argv.h or argv.help
    console.log """
  usage: tsc [file ...] [-f FORMAT]

  tsc - (t)ime (s)eries (c)hart

  Parse timestamps from lines of input and graph it using Vue and Chart.js. The
  chart includes:

  - aggregation by adjustable duration
  - limiting to most recent timestamps

  Each timestamp has a weight of 1, so that default aggregation amounts to simply
  counting timestamps. Weight can be changed by including a number with each
  timestamp, either before or after the timestamp and separated by comma or tab,
  for example:

      2019-08-29,12
      24,2019-08-30
      26,2019-09-01

  Timestamps are parsed strictly.

  -f/--format <moment format string>

      Without a format, falls back on moment's default parsing, otherwise
      parsing will use your format:

      https://momentjs.com/docs/#/parsing/string/
      https://momentjs.com/docs/#/parsing/string-format/
    """
    process.exit()

  content = ''
  if not process.stdin.isTTY
    content += await getStdin()

  argv._.forEach (filename) ->
    if filename is '-'
      content += await getStdin()
    else
      content += fs.readFileSync(filename).toString()

  points = []
  format = argv.f or argv.format or undefined
  isNumber = (s) -> s.toString().replace(/,/g, '').match(/^([\-\+])?[\d\.]+$/)
  isMoment = (s) -> moment.utc(s, format, true).isValid()

  content.split('\n').forEach (line, i) ->
    [t, y] = line.split(/\s*[\t,]\s*/)
    return unless t or y
    t = if t then t.trim()
    y = if y then y.trim()
    if isNumber(t)
      unless isMoment(y)
        console.warn "missing timestamp on line #{i+1}: #{line}"
        return
      points.push
        t: moment.utc(y, format, true)
        y: parseFloat(t)
    else if isMoment(t)
      y = if y and isNumber(y) then y else 1
      points.push
        t: moment.utc(t, format, true)
        y: parseFloat(y)
    else
      console.warn "skipping line #{i+1}: #{line}"

  if points.length is 0
    console.error "no data points found"
    process.exit(1)

  chartFile = "#{__dirname}/../dist/vue-chart.html"
  if not fs.existsSync(chartFile)
    console.error "'#{chartFile}' does not exist, run `pug-pack -p` and try again"
    process.exit(2)

  dir = tmp.dirSync()
  tmpChart = "#{dir.name}/vue-chart.html"
  chartHtml = fs.readFileSync(chartFile).toString().replace /(globalPoints\s*=\s*)\[\]/, '$1' + JSON.stringify(points)
  fs.writeFileSync tmpChart, chartHtml
  console.log "graphing #{points.length} points via #{tmpChart}"

  if points.length > 1000
    # divide into 10ths
    span = moment(points[points.length-1].t).diff(moment(points[0].t))/1000
    gb = if span < 60
      '5s'
    else if span < 3600           # an hour
      '5m'
    else if span < 3600*24        # a day
      '1h'
    else if span < 3600*24*7      # a week
      '1d'
    else if span < 3600*24*30*6   # six months
      '1w'
    else
      '1M'
    chartHtml = fs.readFileSync(tmpChart).toString().replace /(initialGroupBy\s*=\s*)null/, "$1'#{gb}'"
    fs.writeFileSync tmpChart, chartHtml

  execSync "open '#{tmpChart}'"
