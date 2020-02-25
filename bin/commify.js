#!/usr/bin/env node

const child = require('child_process');
const comm = require('../src/commify');

const usage = `usage: commify [-j] [NUMBER ...]

Inserts commas as thousands separators in one or more NUMBER, and outputs each
on its own line. -j outputs as JSON for Alfred Workflow integration.`

if (process.argv.slice().find(function(arg) { return arg.match(/^-(h|-help)$/i) })) {
    console.log(usage)
    process.exit()
}

// https://github.com/shrpne/from-exponential
// ...install, minify, beautify, prune
function r(r) {
    return Array.isArray(r) ? r : String(r).split(/[eE]/);
}
function fromExp(e) {
    const t = r(e);
    if (! function(e) {
            const t = r(e);
            return !Number.isNaN(Number(t[1]));
        }(t)) return t[0];
    let n = "-" === t[0][0] ? "-" : "", u = t[0].replace(/^-/, "").split("."), i = u[0], f = u[1] || "", o = Number(t[1]);
    if (0 === o) return n + i + "." + f;
    if (o < 0) {
        const s = i.length + o;
        if (s > 0) return n + i.substr(0, s) + "." + i.substr(s) + f;
        let a = "0.";
        for (o += 1; o;) a += "0", o += 1;
        return n + a + i + f;
    }
    const c = f.length - o;
    if (c > 0) {
        const p = f.substr(o);
        return n + i + f.substr(0, o) + "." + p;
    }
    for (var b = -c, d = ""; b;) d += "0", b -= 1;
    return n + i + f + d;
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
