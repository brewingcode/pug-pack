#!/usr/bin/env node

const mdtable = require('../src/mdtable')
const fs = require('fs')

const argv = require('minimist')(process.argv.slice(2), {
  boolean: ['h', 'help', 's', 'strict', 'w', 'whitespace'] 
})

const usage = `usage: mdtable [options and filename(s)]

Reads lines from filename(s) and/or stdin and outputs them in a nicely
formatted Markdown table.

-r REGEX     regex used to split each row into cells ("\t" by default)
-a ALIGN     string of "l", "r", and "c" to specify alignments for each cell
-n NAMES     CSV of header names (if first line of input is not headers)
-t N         number of characters to truncate each cell to
-i INDEXES   CSV of 1-based indexes to specify cells to include
-e INDEXES   CSV of 1-based indexes to specify cells to exclude
-s           flag for strict: only include lines that parse to the same number
             of cells as the first line of input
-w           flag for whitespace: infer cells based on how whitespace is laid
             out on first line of input (see docker's CLI output)

Long args are also supported: --regex, --align, --names, --truncate,
--include/--indexes, --exclude, --strict, and --whitespace. A filename of "-"
will read from stdin.`

if (argv.help || argv.h) {
  console.log(usage)
  process.exit(0)
}

let regex = argv.regex || argv.r
const align = argv.align || argv.a
const names = argv.names || argv.n
const truncate = argv.truncate || argv.t
let indexes = argv.indexes || argv.include || argv.i
let exclude = argv.exclude || argv.e
let strict = argv.strict || argv.s
let whitespace = argv.whitespace || argv.w

if (indexes && exclude) {
  console.error('-i and -e cannot be used at the same time')
  process.exit(1)
}

if (regex && whitespace) {
  console.error('-r and -w cannot be used at the same time')
  process.exit(2)
}

regex = regex ? new RegExp(regex, 'i') : /\t/

if (indexes) {
  indexes = indexes.toString().split(',').map(parseFloat)
}
if (exclude) {
  exclude = exclude.toString().split(',').map(parseFloat)
}

const lines = []
let lineNumber = 0

function finish() {
  if (names) {
    lines.unshift(names.toString().split(','))
  }
  console.log(mdtable(lines, {align}));
}

function add(str) {
  str.toString().split('\n').forEach(function(line) {
    lineNumber++

    if (!line.match(/\S/)) {
      return
    }

    if (whitespace === true) {
      // init
      whitespace = []
      let space = 2
      for (let i = 0; i < line.length; i++) {
        if (line[i].match(/\s/)) {
          space++
        }
        else if (space >= 2) {
          space = 0
          whitespace.push(i)
        }
      }
    }

    let cells = []
    if (typeof whitespace === 'object') {
      for (let i = 0; i < whitespace.length; i++) {
        const end = i === whitespace.length - 1 ? undefined : whitespace[i+1]
        cells.push(line.slice(whitespace[i], end))
      }
    }
    else {
      cells = line.split(regex)
    }

    if (strict === true) {
      // init
      strict = cells.length
    }
    if (typeof strict === 'number') {
      if (cells.length !== strict) {
        console.warn(`skipping line ${lineNumber}: expected ${strict} cells, but saw ${cells.length}`)
        return
      }
    }

    if (!isNaN(truncate)) {
      cells = cells.map(function(cell) {
         return cell.slice(0, truncate)
      })
    }

    const reordered = []
    if (indexes) {
      for (let i of indexes) {
        i = i < 0 ? cells.length + i : i - 1
        reordered.push(cells[i])
      }
    }
    if (exclude) {
      for (let i = 0; i < cells.length; i++) {
        let keep = true
        for (let e of exclude) {
          e = e < 0 ? cells.length + e : e - 1
          if (i === e) {
            keep = false
          }
        }
        if (keep) {
          reordered.push(cells[i])
        }
      }
    }

    lines.push(reordered.length ? reordered : cells)
  })
}

argv._.forEach(function(arg) {
  if (arg === '-') { arg = '/dev/stdin' }
   add(fs.readFileSync(arg))
})

if (!process.stdin.isTTY || argv._.length === 0) {
  let stdin = ''
  process.stdin
    .on('data', function(chunk) { stdin += chunk })
    .on('end', function() {
      add(stdin)
      finish()
    })
}
else {
  finish()
}
