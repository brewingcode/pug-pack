pr = require 'bluebird'
fs = pr.promisifyAll require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
pug = require 'pug'
coffeescript = require 'coffee-script'
uglify = require 'uglify-js'
styl = pr.promisifyAll require 'stylus'
svgo = require 'svgo'
uglifycss = require 'uglifycss'
{ execAsync } = pr.promisifyAll require 'child_process'
{ log } = console

module.exports =
  prod: process.env.NODE_ENV
  dist: "#{__dirname}/../dist"
  vars: {}

  pug: (dir, file) ->
    out = file.replace /\.pug$/i, '.html'
    out = out.replace new RegExp(dir, 'i'), @dist
    @vars.pretty = not @prod
    mkdirp.sync @dist
    fs.writeFileAsync out, pug.renderFile file, @vars

  jsfilter: (js) ->
    new pr (resolve) =>
      if @prod
        r = uglify.minify js
        throw r.error if r.error
        resolve r.code
      else
        resolve js

  js: (file) ->
    fs.readFileAsync(file, 'utf8').then (js) => @jsfilter js

  coffee: (file) ->
    coffee = fs.readFileSync file, 'utf8'
    js = coffeescript.compile coffee,
      bare: true
      filename: file
      map: not @prod
      inlineMap: not @prod
    @jsfilter js

  cssfilter: (css) ->
    new pr (resolve) =>
      resolve if @prod then uglifycss.processString(css) else css

  styl: (file) ->
    styl.renderAsync fs.readFileSync(file, 'utf8'),
      filename: file
    .then (css) =>
      @cssfilter css

  css: (file) ->
    fs.readFileAsync(file, 'utf8').then (css) => @cssfilter css

  svg: (file) ->
    log 'svg:', file
    new pr (resolve) ->
      { name } = path.parse file

      plugins = []
      plugins.push
        addClassesToSVGElement:
          classNames: [name]
      plugins.push
        removeDimensions: true

      new svgo { plugins }
      .optimize fs.readFileSync(file, 'utf8'), (svg) ->
        resolve svg.data

  crawl: (root, pug) ->
    execAsync("find '#{path.resolve path.resolve(), root}' -type f -print0").then (stdout) =>
      pug_files = []
      other_files = []

      stdout.split('\0').forEach (f) =>
        return unless f
        { dir, name, ext } = path.parse f
        ext = ext.replace /^\./, ''
        if name.match(/^_/) or not this[ext]
          log "skip: #{f}"
        else if ext is 'pug'
          pug_files.push [ dir, f ]
        else
          other_files.push [ f, name, ext ]

      pr.each other_files, ([f, name, ext]) =>
        log 'reduce:', f
        @vars[ext] = {} unless @vars[ext]
        this[ext](f).then (r) =>
          log "#{ext}: returned #{r.length} chars"
          @vars[ext][name] = r
      .then =>
        if pug
          pr.each pug_files, ([dir, f]) =>
            log 'pug:', f
            @pug dir, f
      .then ->
        log 'done'
      .catch console.error

  self: ->
    @crawl __dirname, true
