#!/usr/bin/env coffee

build = require './_build'
argv = require('yargs').argv

build.prod = argv.p or argv.prod or argv.production
build.dist = if argv._.length > 1 then argv._[1] else './dist'

src = if argv._.length > 0 then argv._[0] else './src'

build.crawl(__dirname, false).then ->
  build.crawl src, true
