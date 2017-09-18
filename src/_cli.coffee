#!/usr/bin/env coffee

build = require './_build'

paths = []
process.argv.slice(2).forEach (a) ->
  if a in ['-p', '--prod', '--production']
    build.prod = true
  else if a in ['-h', '--help']
    console.log """
usage: ./static-page [src] [dist] [-p | --prod | --production]"
default: ./static-page ./src ./dist
"""
    process.exit 0
  else
    paths.push a

src = if paths.length > 0 then paths[0] else './src'
build.dist = if paths.length > 1 then paths[1] else './dist'

build.crawl(__dirname, false).then ->
  build.crawl src, true
