#!/usr/bin/env coffee

build = require './build'
browserSync = require 'browser-sync'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
argv = require('minimist') process.argv.slice(2),
  boolean: ['p', 'prod', 'production', 'w', 'watch', 'v', 'verbose', 'V', 'version',
    'init', 'i']

if argv.h or argv.help
  console.log """
usage:

pug-pack [src] [dist] [-p|--prod|--production] [-w|--watch]
  [-v|--verbose]

pug-pack [-l|--list] [-i|--init] [-h|--help] [-V|--version]

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
    baseAssets = Object.keys build.vars.src
    for k in baseAssets
      console.log k, build.vars.files[k]
    build.crawl(src, true).then ->
      console.log '## assets from you'
      Object.keys(build.vars.src).filter (x) ->
        x not in baseAssets
      .forEach (x) -> console.log x, build.vars.files[x]

else if argv.i or argv.init
  if fs.existsSync './package.json'
    pkg = JSON.parse fs.readFileSync './package.json'
    touched = 0

    update = (name, cmd) ->
      pkg.scripts ?= {}
      if pkg.scripts[name]
        console.warn "'#{name}' run-script already exists"
        return 0
      else
        pkg.scripts[name] = cmd
        return 1

    touched += update 'dev', 'pug-pack --watch'
    touched += update 'build', 'pug-pack --production'
    if touched > 0
      fs.writeFileSync 'package.json', JSON.stringify pkg, null, '  '
      console.log 'package.json updated with "dev" and/or "build" run-scripts'
  else
    console.warn 'no package.json file found, run-scripts not written'

  if not fs.existsSync src
    console.log "creating 'src' directory"
    mkdirp.sync src

  if fs.existsSync "#{src}/base.pug"
    console.warn "#{src}/_base.pug already exists, not modifying it"
  else
    console.log "writing 'src/_base.pug' as an example default layout"
    fs.copyFileSync "#{__dirname}/../src/_base.pug", "#{src}/_base.pug"

  if fs.existsSync "#{src}/index.pug"
    console.warn "#{src}/index.pug already exists, not modifying it"
  else
    console.log "writing 'src/index.pug' as an example index file"
    fs.writeFileSync "#{src}/index.pug", """
      extends _base
      append head
        :inject(file="bootstrap.css")
      append body
        .container-fluid
          p Hello from pug-pack and Bootstrap
    """

  console.log "run 'pug-pack -w' to build and view the example index file in 'dist/index.html'"

else
  fullBuild()
