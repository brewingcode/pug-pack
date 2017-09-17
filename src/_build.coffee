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
{ exec } = require 'child_process'
{ log } = console

module.exports =
  prod: process.env.NODE_ENV
  src: __dirname
  dist: "#{__dirname}/../dist"

  pug: (file, opts) ->
    out = file.replace /\.pug$/i, '.html'
    out = out.replace new RegExp(@src, 'i'), @dist
    opts.pretty = not @prod
    mkdirp.sync @dist
    fs.writeFileAsync out, pug.renderFile file, opts

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
      .define 'inline-url', styl.url paths: [dir]
      .render (err, css) -> resolve(css)

  main: ->
    exec "find '#{@src}' -type f -print0", (err, stdout, stderr) =>
      pug_files = []
      other_files = []

      stdout.split('\0').forEach (f) =>
        return unless f
        { dir, name, ext } = path.parse f
        ext = ext.replace /^\./, ''
        if name.match(/^_/) or not this[ext]
          log "skip: #{f}"
        else if ext is 'pug'
          pug_files.push f
        else
          other_files.push [f, dir, name, ext]

      pr.reduce other_files, (vars, [f, dir, name, ext]) =>
        log 'reduce:', f
        vars[ext] = {} unless vars[ext]
        this[ext](f).then (r) =>
          log "#{ext}: returned #{r.length} chars"
          vars[ext][name] = r
          vars
      , {}
      .then (vars) =>
        pr.each pug_files, (f) =>
          log 'pug:', f
          @pug f, vars
      .then ->
        log 'done'
      .catch console.error
