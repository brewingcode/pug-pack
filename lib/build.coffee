pr = require 'bluebird'
fs = pr.promisifyAll require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'
pug = require 'pug'
coffeescript = require 'coffeescript'
uglify = require 'uglify-es'
styl = require 'stylus'
svgo = require 'svgo'
csso = require 'csso'
htmlmin = require 'html-minifier'
yaml = require 'js-yaml'
{ execAsync } = pr.promisifyAll require 'child_process'

log = ->
  if self.verbose
    console.log.apply(null, arguments)

module.exports = self =
  prod: process.env.NODE_ENV
  dist: "#{__dirname}/../dist"
  verbose: false
  vars:
    src: {}
    files: {}
    filters:
      inject: (text, options) ->
        log 'inject:', text.replace(/\n/g, '').slice(0, 60) + '...', options
        { ext, srcname } = self.parsename options.filename
        if text
          if ext is 'pug'
            ext = options.ext
          if ext is 'svg'
            out = self.vars.src[srcname] or
              throw new Error "no content found for #{srcname}"
          else
            out = self.exts[ext](text) or
              throw new Error "no content found for extension #{ext}"
        else
          # we need to read from ... something
          if ext isnt 'pug'
            out = self.vars.src[srcname]
          else
            if not options.file
              throw new Error ":inject() is missing 'file' attribute: #{options.filename}"
            { srcname, ext } = self.parsename options.file
            out = self.vars.src[srcname] or
              throw new Error "no content found for #{srcname}"

        if ext is 'svg'
          if options.css
            className = srcname.replace /[^\w\-\d]+/g, '-'
            out = self.exts.css """
              .#{className} {
                background-image: url('data:image/svg+xml;utf8,#{out.forCSS}');
              }
            """
            ext = 'css'
          else
            out = out.forDOM

        if ext in ['js', 'coffee']
          out = "<script>\n#{out}\n</script>"
        else if ext in ['css', 'styl']
          out = "<style>\n#{out}\n</style>"

        out

  # replacement for path.parse(), but in the context of this module
  parsename: (f) ->
    parts = path.parse f
    parts.ext = parts.ext.replace /^\./, ''
    parts.absfile = path.resolve self.vars.basedir, f
    parts.absdir = path.resolve self.vars.basedir
    parts.srcname = parts.absfile.replace(new RegExp(parts.absdir, 'i'), '').replace(/^\//, '')
    self.vars.files[parts.srcname] = parts.absfile
    parts

  pug: (file, outfile) ->
    log 'pug:', file, outfile, self.vars.basedir, self.dist
    destFile = path.join self.dist, outfile
    mkdirp.sync path.dirname destFile
    self.vars.pretty = not self.prod
    fs.writeFileAsync destFile, pug.renderFile file, self.vars

  # call as either transform(filename) or transform(ext, text)
  transform: (args...) ->
    if args.length is 1
      filename = args[0]
      s = fs.readFileSync filename, 'utf8'
      { ext } = self.parsename filename
    else
      [ ext, s ] = args
      filename = 'inline'

    pr.try ->
      self.exts[ext](s, filename)
    .catch (err) ->
      console.error 'transform error:', err

  # each of these takes the same two arguments:
  # - some text content
  # - the filename, purely for reference (sourcemaps, etc)
  # all of them are syncronous, EXCEPT for:
  # - svg
  exts:
    js: (s) ->
      if self.prod
        r = uglify.minify s
        throw r.error if r.error
        r.code
      else
        s

    coffee: (s, filename) ->
      js = coffeescript.compile s,
        bare: true
        filename: filename
        map: not self.prod
        inlineMap: not self.prod
      self.exts.js js

    css: (s) ->
      if self.prod
        csso.minify(s, comments:false).css
      else
        s

    styl: (s) ->
      css = styl(s)
        .include self.vars.basedir
        .render()
      self.exts.css css

    svg: (s, filename) ->
      pr.try ->
        { name } = self.parsename filename

        plugins = []
        prs = []

        plugins.push
          removeDimensions: true

        prs.push pr.try ->
          new svgo( {plugins} ).optimize s

        plugins.push
          addClassesToSVGElement:
            classNames: [name]
        plugins.push
          removeXMLNS: true

        prs.push pr.try ->
          new svgo( {plugins} ).optimize s

        pr.all(prs).then ([forCSS, forDOM]) ->
          forCSS: forCSS.data
          forDOM: forDOM.data

    html: (s) ->
      if self.prod
        htmlmin.minify(s)
      else
        s

    json: (s) -> JSON.parse s

    yml: (s) -> yaml.load s

  # crawls the filesystem and always does one thing, and usually does a second:
  # 1. find all non-pug files to transform into pug variable (sync AND async)
  # 2. do the pug compilation, which CANNOT do async...unless you want set
  # `skipPug`, because you're just dumping info about what happened in stage
  # 1, for example
  crawl: (rootDir, skipPug) ->
    self.vars.basedir = path.resolve rootDir

    execAsync("find '#{self.vars.basedir}' -type f -print0").then (stdout) =>
      pug_files = []
      other_files = []

      stdout.split('\0').forEach (f) =>
        return unless f
        { name, ext, srcname } = self.parsename f
        if name.match(/^_/)
          log "skip: #{f}"
          self.vars.src[srcname] = null
        else if ext is 'pug'
          pug_files.push f
          self.vars.src[srcname] = null
        else if self.exts[ext]
          other_files.push f

      pr.each other_files, (f) =>
        log 'reading:', f
        { srcname } = self.parsename f
        unless self.vars.src[srcname]
          self.transform(f).then (out) =>
            self.vars.src[srcname] = out
      .then =>
        unless skipPug
          pr.each pug_files, (f) =>
            outfile = f.replace /\.pug$/i, '.html'
            { srcname } = self.parsename outfile
            self.pug f, srcname
    .catch console.error

  self: (testPug) ->
    self.crawl("#{__dirname}/../src").then =>
      if testPug
        self.crawl("#{__dirname}/../test", true)
