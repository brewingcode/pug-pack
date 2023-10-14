#!/usr/bin/env node
//!/usr/bin/env coffee
var argv, csv, execSync, fs, getStdin, moment, tmp;

fs = require('fs');

argv = require('minimist')(process.argv.slice(2), {
  boolean: ['h', 'help']
});

moment = require('moment');

tmp = require('tmp');

({execSync} = require('child_process'));

getStdin = require('get-stdin');

csv = require('csv-parse/sync');

moment.suppressDeprecationWarnings = true;

(async function() {
  var chartFile, chartHtml, content, dir, format, gb, isMoment, isNumber, points, span, tmpChart;
  if (argv.h || argv.help) {
    console.log(`usage: tsc [file ...] [-f FORMAT]

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
    https://momentjs.com/docs/#/parsing/string-format/`);
    process.exit();
  }
  content = '';
  if (!process.stdin.isTTY) {
    content += (await getStdin());
  }
  argv._.forEach(async function(filename) {
    if (filename === '-') {
      return content += (await getStdin());
    } else {
      return content += fs.readFileSync(filename).toString();
    }
  });
  points = [];
  format = argv.f || argv.format || void 0;
  isNumber = function(s) {
    return s.toString().replace(/,/g, '').match(/^([\-\+])?[\d\.]+$/);
  };
  isMoment = function(s) {
    return moment.utc(s, format, true).isValid();
  };
  csv.parse(content).forEach(function(row) {
    var t, y;
    [t, y] = row;
    if (!(t || y)) {
      return;
    }
    t = t ? t.trim() : void 0;
    y = y ? y.trim() : void 0;
    if (isNumber(t)) {
      if (!isMoment(y)) {
        console.warn(`missing timestamp in row: ${row}`);
        return;
      }
      return points.push({
        t: moment.utc(y, format, true),
        y: parseFloat(t)
      });
    } else if (isMoment(t)) {
      y = y && isNumber(y) ? y : 1;
      return points.push({
        t: moment.utc(t, format, true),
        y: parseFloat(y)
      });
    } else {
      return console.warn(`skipping row: ${row}`);
    }
  });
  if (points.length === 0) {
    console.error("no data points found");
    process.exit(1);
  }
  chartFile = `${__dirname}/../dist/vue-chart.html`;
  if (!fs.existsSync(chartFile)) {
    console.error(`'${chartFile}' does not exist, run \`pug-pack -p\` and try again`);
    process.exit(2);
  }
  dir = tmp.dirSync();
  tmpChart = `${dir.name}/vue-chart.html`;
  chartHtml = fs.readFileSync(chartFile).toString().replace(/(globalPoints\s*=\s*)\[\]/, '$1' + JSON.stringify(points));
  fs.writeFileSync(tmpChart, chartHtml);
  console.log(`graphing ${points.length} points via ${tmpChart}`);
  if (points.length > 1000) {
    // divide into 10ths
    span = moment(points[points.length - 1].t).diff(moment(points[0].t)) / 1000;
    gb = span < 60 ? '5s' : span < 3600 ? '5m' : span < 3600 * 24 ? '1h' : span < 3600 * 24 * 7 ? '1d' : span < 3600 * 24 * 30 * 6 ? '1w' : '1M'; // an hour // a day // a week // six months
    chartHtml = fs.readFileSync(tmpChart).toString().replace(/(initialGroupBy\s*=\s*)null/, `$1'${gb}'`);
    fs.writeFileSync(tmpChart, chartHtml);
  }
  return execSync(`open '${tmpChart}'`);
})();
