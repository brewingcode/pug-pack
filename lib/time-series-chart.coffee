#!/usr/bin/env coffee

fs = require 'fs'
argv = require('minimist') process.argv.slice(2)
moment = require 'moment'
tmp = require 'tmp'
{ execSync } = require 'child_process'

content = ''
if not process.stdin.isTTY
  content += fs.readFileSync('/dev/stdin').toString()

argv._.forEach (filename) ->
  content += fs.readFileSync(filename).toString()

points = []
format = argv.f or argv.format or undefined
isNumber = (s) -> s.toString().replace(/,/g, '').match(/^[\d\-\+\.]+$/)
isMoment = (s) -> moment(s, format, true).isValid()

content.split('\n').forEach (line) ->
  [t, y] = line.split(/\s*[\t,]\s*/)
  return unless t or y
  if isMoment(t)
    y = if y and isNumber(y) then y else 1
    points.push
      t: moment(t, format, true)
      y: parseFloat(y)
  else if isMoment(y)
    t = if t and isNumber(t) then t else 1
    points.push
      t: moment(y, format, true)
      y: parseFloat(t)
  else
    console.warn "skipping: #{line}"

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
