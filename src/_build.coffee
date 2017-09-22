pr = require 'bluebird'
fs = pr.promisifyAll require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
pug = require 'pug'
coffeescript = require 'coffee-script'
uglify = require 'uglify-js'
styl = require 'stylus'
svgo = require 'svgo'
uglifycss = require 'uglifycss'
htmlmin = require 'html-minifier'
yaml = require 'js-yaml'
{ execAsync } = pr.promisifyAll require 'child_process'
{ log } = console

module.exports = self =
  prod: process.env.NODE_ENV
  dist: "#{__dirname}/../dist"
  vars:
    data: {}
    filters:
      inject: (text, options) ->
        log 'inject:', text.replace(/\n/g, '').slice(0, 60) + '...', options
        { ext } = path.parse options.filename
        ext = ext.replace /^\./, ''
        if not text
          # we need to read from ... something
          if ext isnt 'pug'
            return self.transform options.filename
          if not options.file
            throw new Error ":inject() is missing 'file' attribute: #{options.filename}"

          file = "#{self.vars.basedir}/#{options.file}"
          { ext } = path.parse file
          ext = ext.replace /^\./, ''
          return self.transform file
        else
          if ext is 'pug'
            ext = options.ext
          return self.transform ext, text

  pug: (dir, file) ->
    out = file.replace /\.pug$/i, '.html'
    out = out.replace new RegExp(dir, 'i'), @dist
    mkdirp.sync @dist
    @vars.basedir = dir
    @vars.pretty = not @prod
    fs.writeFileAsync out, pug.renderFile file, @vars

  transform: (args...) ->
    # call as either transform(filename) or transform(ext, text)
    if args.length is 1
      filename = args[0]
      s = fs.readFileSync filename, 'utf8'
      { ext } = path.parse filename
      ext = ext.replace /^\./, ''
      filename = filename.replace new RegExp(@vars.basedir+'/', 'i'), '' # for source maps
    else
      [ ext, s ] = args
      filename = 'inline'

    exts =
      js: =>
        if @prod
          r = uglify.minify s
          throw r.error if r.error
          r.code
        else
          s

      coffee: =>
        js = coffeescript.compile s,
          bare: true
          filename: filename
          map: not @prod
          inlineMap: not @prod
        @transform 'js', js

      css: =>
        if @prod
          uglifycss.processString(s)
        else
          s

      styl: => @transform 'css', styl.render s

      svg: =>
        return 'n/a'
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

      html: =>
        if @prod
          htmlmin.minify(s)
        else
          s

    try
      exts[ext]()
    catch err
      console.error 'transform error:', args
      throw err

  json: (text) -> JSON.parse text

  yml: (text) -> yaml.load text

  crawl: (root, pug) ->
    execAsync("find '#{path.resolve path.resolve(), root}' -type f -print0").then (stdout) =>
      pug_files = []
      other_files = []

      stdout.split('\0').forEach (f) =>
        return unless f
        { dir, name, ext } = path.parse f
        ext = ext.replace /^\./, ''
        if name.match(/^_/)
          log "skip: #{f}"
        else if ext is 'pug'
          pug_files.push [ dir, f ]
        else if ext in ['json', 'yml']
          other_files.push [ f, ext ]

      pr.each other_files, ([f, ext]) =>
        log 'reading:', f
        name = f.replace new RegExp(root+'/', 'i'), ''
        unless @vars.data[name]
          @vars.data[name] = this[ext](fs.readFileSync f, 'utf8')
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
