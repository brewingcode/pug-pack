#!/usr/bin/env coffee

build = require './_build'
nodemon = require 'nodemon'
{ quote } = require 'shell-quote'
fs = require 'fs'

paths = []
watch =
  run: false
  args: []

process.argv.slice(2).forEach (a) ->
  if a in ['-p', '--prod', '--production']
    build.prod = true
    watch.args.push a
  else if a in ['-h', '--help']
    console.log """
usage: ./static-page [src] [dist]
  [-p | --prod | --production]
  [-w | --watch]"

default: ./static-page ./src ./dist
"""
    process.exit()
  else if a in ['-w', '--watch']
    watch.run = true
  else
    paths.push a
    watch.args.push a

src = if paths.length > 0 then paths[0] else './src'
build.dist = if paths.length > 1 then paths[1] else './dist'

if watch.run > 0
  watch.args.unshift "#{__dirname}/_cli.coffee"
  nodemon
    watch: src
    ext: 'pug js coffee css styl svg'
    exec: quote watch.args
    verbose: true
  .on 'log', ({type, message, colour}) ->
    if type is 'detail'
      if fs.existsSync message
        console.log colour
    else if message
      console.log colour
  .on 'quit', -> process.exit()
else
  build.crawl(__dirname, false).then ->
    build.crawl src, true
