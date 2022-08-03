#!/usr/bin/env node --max-old-space-size=8000

const mdtable = require('../src/mdtable')
const fs = require('fs')
const csvparse = require('csv-parse')
const readline = require('readline')
const JSONStream = require('JSONStream')

try {
  const csvstringify = require('csv-stringify/sync')
}
catch (e) {
  const csvstringify = require('csv-stringify/dist/cjs/sync.cjs')
}

const argv = require('minimist')(process.argv.slice(2), {
  boolean: ['h', 'help', 's', 'strict', 'w', 'whitespace', 'p', 'plaintext',
    'j', 'json', 'c', 'csv', 'C', 'csv-out', '-J', 'json-out', 'A'],
})

const usage = `usage: mdtable [options and filename(s)]

Reads lines from filename(s) or stdin and outputs them in a nicely
formatted Markdown table.

Input options:

-i INDEXES   include columns via 1-based indexes in CSV form (eg "2,-1,4")
-e INDEXES   exclude columns via 1-based indexes in CSV form
-r REGEX     regex used to split each row into cells ("\\t" by default)
-f N         force number of columns to N by combining columns, starting
             from the right and working back to the left
-w           whitepsace-based inference for column boundaries: use the first
             line as a template (eg, see Docker's CLI output)
-j           json-formatted input (ignore -r and -w)
-c           csv-formatted input (ignore -r and -w)

Output options:

-a ALIGN     align each cell with "l", "r", and "c" (eg "llr")
-A           omit alignment row (not strictly valid markdown table)
-n NAMES     names for column headers as CSV (if first line of input is not
             headers)
-t N         truncate all cells to N characters
-p           plaintext output: un-markdownify the final result
-s           strict parsing: only output lines that parse to the same number
             of cells as the first line of input
-C           output as CSV
-J           output as JSON

Long args are also supported: --regex, --force, --align, --names, --truncate,
--include/--indexes, --exclude, --strict, --whitespace, --plaintext, --json,
--json-out, --csv, --csv-out. A filename of "-" will read from stdin.

-a and -n are used AFTER -i and -e. i.e., if you -i three columns, you should
ALSO pass three values for -a and/or -n.`

if (argv.help || argv.h) {
  console.log(usage)
  process.exit(0)
}

let regex = argv.regex || argv.r
const force = argv.force || argv.f
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
const outCSV = argv['out-csv'] || argv.C
const outJSON= argv['out-json'] || argv.J
const noAlign = argv['no-align'] || argv.A

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

function finish() {
  allLines.sort(function(a,b) { return a[0] - b[0] })
  const modifiedLines = allLines.map(function(line, i) {
    let cells = line[1]
    if (strict === true) {
      // init
      strict = cells.length
    }
    if (typeof strict === 'number') {
      if (cells.length !== strict) {
        console.warn(`skipping line ${i+1}: expected ${strict} cells, but saw ${cells.length}`)
        return false
      }
    }

    if (!isNaN(truncate)) {
      cells = cells.map(function(cell) {
         return cell.slice(0, truncate)
      })
    }

    if (force) {
      if (cells.length > force) {
        const lastCell = cells.slice(force-1).join(' ')
        cells.splice(force-1, cells.length, lastCell)
      }
    }
    return reordered(cells)
  }).filter(Boolean)

  if (names) {
    modifiedLines.unshift(names.toString().split(','))
  }

  if (outCSV || outJSON) {
    modifiedLines.forEach(function(row) {
      if (outCSV) process.stdout.write(csvstringify.stringify([row]))
      if (outJSON) console.log(JSON.stringify(row))
    })
  }
  else {
    mdtable(modifiedLines, {align, plaintext, noAlign, stream:process.stdout})
  }
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

function read(order, path) {
  return new Promise(function(resolve, reject) {
    let parser

    if (json_in) {
      let first
      parser = JSONStream.parse('*')
      parser.on('data', function(data) {
        if (!first) {
          first = data
          if (!names) {
            names = reordered(Object.keys(first))
          }
        }
        if (typeof(first) === 'string') {
          allLines.push([order, [data]])
        }
        else if (Array.isArray(first)) {
          allLines.push([order, data])
        }
        else {
          allLines.push([order, Object.values(data).map(function(v) {
            return typeof(v) === 'string' ? v : JSON.stringify(v)
          })])
        }
      })
    }
    else if (csv_in) {
      parser = csvparse.parse({
        relax_column_count: true,
        relax_quotes: true,
        bom: true,
      })
      parser.on('readable', function() {
        let rec
        while ((rec = parser.read()) !== null) {
          allLines.push([order, rec])
        }
      })
    }
    else {
      parser = readline.createInterface({
        input: path === '-' ? process.stdin : fs.createReadStream(path),
      })
      parser.on('line', function(line) {
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

        allLines.push([order, cells])
      })

      parser.on('close', resolve)
      parser.on('error', reject)
      return // readline doesn't match the events or flow of streams
    }

    parser.on('end', resolve)
    parser.on('error', reject)
    const stream = path === '-' ? process.stdin : fs.createReadStream(path)
    stream.pipe(parser)
  })
}

const prs = []
if (!process.stdin.isTTY || argv._.length === 0) {
  prs.push(read(0, '-'))
}
else {
  argv._.forEach(function(arg, i) {
    prs.push(read(i, arg))
  })
}
Promise.all(prs).then(finish)
