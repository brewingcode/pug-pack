#!/usr/bin/env node

const mdtable = require('../src/mdtable')
const fs = require('fs')
const csvparse = require('csv-parse/lib/sync')

const argv = require('minimist')(process.argv.slice(2), {
  boolean: ['h', 'help', 's', 'strict', 'w', 'whitespace', 'p', 'plaintext',
    'j', 'json', 'c', 'csv'],
})

const usage = `usage: mdtable [options and filename(s)]

Reads lines from filename(s) and/or stdin and outputs them in a nicely
formatted Markdown table.

Input options:

-i INDEXES   include columns via 1-based indexes in CSV form (eg "2,-1,4")
-e INDEXES   exclude columns via 1-based indexes in CSV form
-r REGEX     regex used to split each row into cells ("\t" by default)
-w           whitepsace-based inference for column boundaries: use the first
             line as a template (eg, see Docker's CLI output)
-j           json-formatted input (ignore -r and -w)
-c           csv-formatted input (ignore -r and -w)

Output options:

-a ALIGN     align each cell with "l", "r", and "c" (eg "llr")
-n NAMES     names for column headers as CSV (if first line of input is not
             headers)
-t N         truncate all cells to N characters
-p           plaintext output: un-markdownify the final result
-s           strict parsing: only output lines that parse to the same number
             of cells as the first line of input

Long args are also supported: --regex, --align, --names, --truncate,
--include/--indexes, --exclude, --strict, --whitespace, --plaintext, --json,
and --csv. A filename of "-" will read from stdin.

-a and -n are used AFTER -i and -e. i.e., if you -i three columns, you should
ALSO pass three values for -a and/or -n.`

if (argv.help || argv.h) {
  console.log(usage)
  process.exit(0)
}

let regex = argv.regex || argv.r
const align = argv.align || argv.a
let names = argv.names || argv.n
const truncate = argv.truncate || argv.t
const json_in = argv.json || argv.j
const csv_in = argv.csv || argv.c
let indexes = argv.indexes || argv.include || argv.i
let exclude = argv.exclude || argv.e
let strict = argv.strict || argv.s
let whitespace = argv.whitespace || argv.w
const plaintext = argv.plaintext || argv.p

if (names) {
    names = names.toString().split(',')
}

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

const allLines = []
let lineNumber = 0

function finish() {
  if (names) {
    allLines.unshift(names.toString().split(','))
  }
  let table = mdtable(allLines, {align})
  if (plaintext) {
    const lines = table.split(/\n/)
    const layout = lines.splice(1,1) // remove second line
    const indexes = []
    const re = / \| /g
    let m
    while (m = re.exec(layout)) {
      indexes.push(m.index)
    }
    table = lines.map(function(line) {
      indexes.forEach(function(i) {
        line = line.substring(0, i) + '\0\0\0' + line.substring(i+3)
      })
      return line.replace(/\0\0\0/g, ' ')
        .replace(/^\| /, '')
        .replace(/ \|$/, '')
    }).join('\n')
  }
  console.log(table)
}

function reordered(cells) {
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

  if (reordered.length) {
    cells = reordered
  }

  return cells
}

function add(str) {
  let lines = []
  if (json_in) {
    lines = JSON.parse(str)
    // use first record as example for all other records
    const first = lines[0]
    if (Array.isArray(first)) {
      // each record is an array, nothing needs to be done
    }
    else {
      if (typeof(first) === 'object') {
        if (!names) {
          names = reordered(Object.keys(first))
        }
        lines = lines.map(function(obj) {
          return Object.values(obj)
        })
      }
      else {
        // some kind of scalar, so uh.... make it an array of one I suppose
        lines = lines.map(function(x) {
          return [x]
        })
      }
    }
  }
  else if (csv_in) {
    lines = csvparse(str)
  }
  else {
    str.toString().split('\n').forEach(function(line) {
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

      lines.push(cells)
    })
  }

  lines = lines.map(function(cells) {
    lineNumber++

    if (strict === true) {
      // init
      strict = cells.length
    }
    if (typeof strict === 'number') {
      if (cells.length !== strict) {
        console.warn(`skipping line ${lineNumber}: expected ${strict} cells, but saw ${cells.length}`)
        return null
      }
    }

    if (!isNaN(truncate)) {
      cells = cells.map(function(cell) {
         return cell.slice(0, truncate)
      })
    }

    return reordered(cells)
  })

  allLines.push(...lines.filter(Boolean))
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
