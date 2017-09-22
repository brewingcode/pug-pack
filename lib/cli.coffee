#!/usr/bin/env coffee

build = require './build'
nodemon = require 'nodemon'
{ quote } = require 'shell-quote'
fs = require 'fs'
argv = require('minimist')(process.argv.slice(2))

if argv.h or argv.help
  console.log """
usage: ./static-page [src] [dist]
  [-p | --prod | --production]
  [-w | --watch]"

default: ./static-page ./src ./dist
"""
  process.exit()

if argv.p or argv.prod or argv.production
  build.prod = true

src = if argv._.length > 0 then argv._[0] else './src'
build.dist = if argv._.length > 1 then argv._[1] else './dist'

if argv.w or argv.watch
  args = [ "#{__dirname}/cli.coffee", src, build.dist ]
  args.push '-p' if build.prod

  nodemon
    watch: src
    ext: '*'
    exec: quote args
    verbose: true
  .on 'log', ({type, message, colour}) ->
    if type is 'detail'
      if fs.existsSync message
        console.log colour
    else if message
      console.log colour
  .on 'quit', -> process.exit()
else
  build.self().then -> build.crawl src, true
