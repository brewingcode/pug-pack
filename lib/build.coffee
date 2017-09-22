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
# { log } = console
log = -> 0

module.exports = self =
  prod: process.env.NODE_ENV
  dist: "#{__dirname}/../dist"
  vars:
    src: {}
    filters:
      inject: (text, options) ->
        log 'inject:', text.replace(/\n/g, '').slice(0, 60) + '...', options
        { ext, srcname } = self.parsename options.filename
        if not text
          # we need to read from ... something
          if ext isnt 'pug'
            out = self.vars.src[srcname]
          else
            if not options.file
              throw new Error ":inject() is missing 'file' attribute: #{options.filename}"
            { srcname, ext } = self.parsename options.file
            out = self.vars.src[srcname]
        else
          if ext is 'pug'
            ext = options.ext
          else if ext is 'svg'
            out = self.vars.src[srcname]
          else
            out = self.exts[ext].call(self, text)

        if ext in ['js', 'coffee']
          "<script>\n#{out}\n</script>"
        else if ext in ['css', 'styl']
          "<style>\n#{out}\n</style>"
        else
          out

  # replacement for path.parse(), but in the context of this module
  parsename: (f) ->
    parts = path.parse f
    parts.ext = parts.ext.replace /^\./, ''
    parts.absfile = path.resolve @basedir, f
    parts.absdir = path.resolve @basedir
    parts.srcname = parts.absfile.replace(new RegExp(parts.absdir, 'i'), '').replace(/^\//, '')
    parts

  pug: (file) ->
    outfile = file.replace /\.pug$/i, '.html'
    { srcname } = @parsename outfile
    outfile = @dist + '/' + srcname

    mkdirp.sync @dist
    @vars.pretty = not @prod
    fs.writeFileAsync outfile, pug.renderFile file, @vars

  # call as either transform(filename) or transform(ext, text)
  transform: (args...) ->
    if args.length is 1
      filename = args[0]
      s = fs.readFileSync filename, 'utf8'
      { ext } = @parsename filename
    else
      [ ext, s ] = args
      filename = 'inline'

    if ext is 'svg'
      @exts[ext].call(this, s, filename)
    else
      try
        pr.resolve @exts[ext].call(this, s, filename)
      catch err
        console.error 'transform error:', args
        throw err

  # each of these takes the same two arguments:
  # - some text content
  # - the filename, purely for reference (sourcemaps, etc)
  # all of them are syncronous, EXCEPT for:
  # - svg
  exts:
    js: (s) ->
      log 'js:', s.replace(/\n/g, '').slice(0,30) + '...'
      if @prod
        r = uglify.minify s
        throw r.error if r.error
        r.code
      else
        s

    coffee: (s, filename) ->
      log 'coffee:', s, filename
      js = coffeescript.compile s,
        bare: true
        filename: filename
        map: not @prod
        inlineMap: not @prod
      @exts.js js

    css: (s) ->
      if @prod
        uglifycss.processString s
      else
        s

    styl: (s) -> @exts.css styl.render s

    svg: (s, filename) ->
      new pr (resolve) ->
        { name } = self.parsename filename

        plugins = []
        plugins.push
          addClassesToSVGElement:
            classNames: [name]
        plugins.push
          removeDimensions: true

        new svgo { plugins }
          .optimize s, (svg) ->
            resolve svg.data

    html: (s) ->
      if @prod
        htmlmin.minify(s)
      else
        s

    json: (s) -> JSON.parse s

    yml: (s) -> yaml.load s

  crawl: (root) ->
    @basedir = path.resolve root

    execAsync("find '#{path.resolve path.resolve(), @basedir}' -type f -print0").then (stdout) =>
      pug_files = []
      other_files = []

      stdout.split('\0').forEach (f) =>
        return unless f
        { name, ext } = @parsename f
        if name.match(/^_/)
          log "skip: #{f}"
        else if ext is 'pug'
          pug_files.push f
        else if @exts[ext]
          other_files.push f

      pr.each other_files, (f) =>
        log 'reading:', f
        { srcname } = @parsename f
        unless @vars.src[srcname]
          @transform(f).then (out) =>
            @vars.src[srcname] = out
      .then =>
        pr.each pug_files, (f) =>
          log 'f:', f
          @pug(f).then -> log 'written'
    .then ->
      log 'done'
    .catch console.error

  self: ->
    @crawl __dirname, true
