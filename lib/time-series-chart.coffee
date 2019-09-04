#!/usr/bin/env coffee

fs = require 'fs'
argv = require('minimist') process.argv.slice(2),
  boolean: ['h', 'help']
moment = require 'moment'
tmp = require 'tmp'
{ execSync } = require 'child_process'
getStdin = require 'get-stdin'

do ->
  if argv.h or argv.help
    console.log """
  tsc - (t)ime (s)eries (c)hart

  usage: tsc [file ...] [-f fmt>]

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
  console.log 'isTTY:', process.stdin.isTTY, typeof process.stdin.isTTY
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
  isMoment = (s) -> moment(s, format, true).isValid()

  content.split('\n').forEach (line, i) ->
    [t, y] = line.split(/\s*[\t,]\s*/)
    return unless t or y
    if isNumber(t)
      console.log "number,timestamp"
      unless isMoment(y)
        console.warn "missing timestamp on line #{i+1}: #{line}"
        return
      points.push
        t: moment(y, format, true)
        y: parseFloat(t)
    else if isMoment(t)
      y = if y and isNumber(y) then y else 1
      console.log "timestamp,#{y}"
      points.push
        t: moment(t, format, true)
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
  chartHtml = fs.readFileSync(chartFile).toString().replace /(globalPoints\s*=\s*)\[\]/, '$1' + JSON.stringify(points)
  fs.writeFileSync "#{dir.name}/vue-chart.html", chartHtml
  console.log "graphing #{points.length} points via #{dir.name}"
  execSync "open '#{dir.name}/vue-chart.html'"
