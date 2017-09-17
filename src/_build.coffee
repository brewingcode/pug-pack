pr = require 'bluebird'
fs = pr.promisifyAll require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
pug = require 'pug'
coffeescript = require 'coffee-script'
uglify = require 'uglify-js'
styl = pr.promisifyAll require 'stylus'
imgsize = require 'image-size'
uglifycss = require 'uglifycss'
{ execAsync } = pr.promisifyAll require 'child_process'
{ log } = console

module.exports =
  prod: process.env.NODE_ENV
  dist: "#{__dirname}/dist"
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
    # actually returns the svg as a CSS class
    new pr (resolve) ->
      data = new Buffer(fs.readFileSync file, 'utf8')
      size = imgsize data
      { dir, name } = path.parse file
      styl """
        .#{name}-svg
          background-image: inline-url("#{file}", "utf8")
          background-size: cover
          width: #{size.width}px
          height: #{size.height}px
          display: inline-block
      """
      .set 'filename', file
      .define 'inline-url', styl.url()
      .render (err, css) -> resolve(css)

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
