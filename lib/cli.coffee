#!/usr/bin/env coffee

build = require './build'
browserSync = require 'browser-sync'
fs = require 'fs'
argv = require('minimist') process.argv.slice(2),
  boolean: ['p', 'prod', 'production', 'w', 'watch', 'v', 'verbose', 'V', 'version']

if argv.h or argv.help
  console.log """
usage:

pug-pack [src] [dist] [-p|--prod|--production] [-w|--watch]
  [-v|--verbose]

pug-pack [-l|--list] [-h|--help] [-V|--version]

default: pug-pack ./src ./dist
"""
  process.exit()

if argv.V or argv.version
  pkg = require('../package.json')
  console.log pkg.version
  process.exit()

if argv.p or argv.prod or argv.production
  build.prod = true

if argv.v or argv.verbose
  build.verbose = true

src = if argv._.length > 0 then argv._[0] else './src'
build.dist = if argv._.length > 1 then argv._[1] else './dist'

fullBuild = ->
  build.self().then ->
    build.crawl(src)

if argv.w or argv.watch
  fullBuild().then ->
    bs = browserSync.create()

    bs.watch src+'/**/*', null, (e) ->
      if e is 'change'
        build.vars.src = {}
        fullBuild().then -> bs.reload()

    bs.init
      server: build.dist
      host: process.env.HOST or '127.0.0.1'

else if argv.l or argv.list
  build.self().then ->
    console.log '## assets from pug-pack'
    pp = Object.keys build.vars.src
    console.log(f) for f in pp
    build.crawl(src, true).then ->
      console.log '## assets from you'
      Object.keys(build.vars.src).filter (x) ->
        x not in pp
      .forEach (x) -> console.log x
else
  fullBuild()
