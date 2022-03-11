#!/usr/bin/env node

const dhms = require('../src/day-hour-min-sec')
const fromExp = require('../src/from-exp')

const usage = `usage: dhms [NUMBER ...]

Convert a number of seconds into human numbers.
`

if (process.argv.slice().find(function(arg) { return arg.match(/^-(h|-help)$/i) })) {
    console.log(usage)
    process.exit()
}

process.argv.slice(2).forEach(function(x) {
    console.log(dhms(fromExp(x)));
});
