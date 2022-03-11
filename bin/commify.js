#!/usr/bin/env node

const child = require('child_process');
const comm = require('../src/commify');
const fromExp = require('../src/from-exp');

const usage = `usage: commify [-j] [NUMBER ...]

Inserts commas as thousands separators in one or more NUMBER, and outputs each
on its own line. -j outputs as JSON for Alfred Workflow integration.`

if (process.argv.slice().find(function(arg) { return arg.match(/^-(h|-help)$/i) })) {
    console.log(usage)
    process.exit()
}

let json = null;
process.argv.slice(2).forEach(function(x) {
    if (x === '-j') {
        json = [];
        return;
    }
    if (x === '-p') {
        x = child.execSync('pbpaste');
    }

    // https://stackoverflow.com/a/2901298/2926055
    const num = comm(fromExp(x));
    if (json) {
        return json.push({
            title: num,
            arg: num,
            text: { largetype: num
        }
        });
    } else {
        return console.log(num);
    }
});

if (json) {
    console.log(JSON.stringify({items:json}));
}
