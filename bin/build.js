var coffeescript, csso, execAsync, fs, htmlmin, log, mkdirp, optimize, path, pr, pug, self, styl, uglify, yaml;

pr = require('bluebird');

fs = pr.promisifyAll(require('fs'));

path = require('path');

mkdirp = require('mkdirp');

pug = require('pug');

coffeescript = require('coffeescript');

uglify = require('uglify-es');

styl = require('stylus');

({optimize} = require('svgo'));

csso = require('csso');

htmlmin = require('html-minifier');

yaml = require('js-yaml');

({execAsync} = pr.promisifyAll(require('child_process')));

log = function() {
  if (self.verbose) {
    return console.log.apply(null, arguments);
  }
};

module.exports = self = {
  prod: process.env.NODE_ENV,
  dist: `${__dirname}/../dist`,
  verbose: false,
  vars: {
    src: {},
    files: {},
    filters: {
      inject: function(text, options) {
        var className, ext, out, srcname;
        log('inject:', text.replace(/\n/g, '').slice(0, 60) + '...', options);
        ({ext, srcname} = self.parsename(options.filename));
        if (text) {
          if (ext === 'pug') {
            ext = options.ext;
          }
          if (ext === 'svg') {
            out = self.vars.src[srcname] || (function() {
              throw new Error(`no content found for ${srcname}`);
            })();
          } else {
            out = self.exts[ext](text) || (function() {
              throw new Error(`no content found for extension ${ext}`);
            })();
          }
        } else {
          // we need to read from ... something
          if (ext !== 'pug') {
            out = self.vars.src[srcname];
          } else {
            if (!options.file) {
              throw new Error(`:inject() is missing 'file' attribute: ${options.filename}`);
            }
            ({srcname, ext} = self.parsename(options.file));
            out = self.vars.src[srcname] || (function() {
              throw new Error(`no content found for ${srcname}`);
            })();
          }
        }
        if (ext === 'svg') {
          if (options.css) {
            className = srcname.replace(/[^\w\-\d]+/g, '-');
            out = self.exts.css(`.${className} {
  background-image: url('data:image/svg+xml;utf8,${out.forCSS}');
}`.replace(/#/g, '%23'));
            ext = 'css';
          } else {
            out = out.forDOM;
          }
        }
        if (ext === 'js' || ext === 'coffee') {
          out = `<script>\n${out}\n</script>`;
        } else if (ext === 'css' || ext === 'styl') {
          out = `<style>\n${out}\n</style>`;
        }
        return out;
      }
    }
  },
  // replacement for path.parse(), but in the context of this module
  parsename: function(f) {
    var parts;
    parts = path.parse(f);
    parts.ext = parts.ext.replace(/^\./, '');
    parts.absfile = path.resolve(self.vars.basedir, f);
    parts.absdir = path.resolve(self.vars.basedir);
    parts.srcname = parts.absfile.replace(new RegExp(parts.absdir, 'i'), '').replace(/^\//, '');
    self.vars.files[parts.srcname] = parts.absfile;
    return parts;
  },
  pug: function(file, outfile) {
    var destFile;
    log('pug:', file, outfile, self.vars.basedir, self.dist);
    destFile = path.join(self.dist, outfile);
    mkdirp.sync(path.dirname(destFile));
    self.vars.pretty = !self.prod;
    return fs.writeFileAsync(destFile, pug.renderFile(file, self.vars));
  },
  // call as either transform(filename) or transform(ext, text)
  transform: function(...args) {
    var ext, filename, s;
    if (args.length === 1) {
      filename = args[0];
      s = fs.readFileSync(filename, 'utf8');
      ({ext} = self.parsename(filename));
    } else {
      [ext, s] = args;
      filename = 'inline';
    }
    return pr.try(function() {
      return self.exts[ext](s, filename);
    }).catch(function(err) {
      return console.error('transform error:', err);
    });
  },
  // each of these takes the same two arguments:
  // - some text content
  // - the filename, purely for reference (sourcemaps, etc)
  // all of them are syncronous, EXCEPT for:
  // - svg
  exts: {
    js: function(s) {
      var r;
      if (self.prod) {
        r = uglify.minify(s);
        if (r.error) {
          throw r.error;
        }
        return r.code;
      } else {
        return s;
      }
    },
    coffee: function(s, filename) {
      var js;
      js = coffeescript.compile(s, {
        bare: true,
        filename: filename,
        map: !self.prod,
        inlineMap: !self.prod
      });
      return self.exts.js(js);
    },
    css: function(s) {
      if (self.prod) {
        return csso.minify(s, {
          comments: false
        }).css;
      } else {
        return s;
      }
    },
    styl: function(s) {
      var css;
      css = styl(s).include(self.vars.basedir).render();
      return self.exts.css(css);
    },
    svg: function(s, filename) {
      return pr.try(function() {
        var name, plugins, prs;
        ({name} = self.parsename(filename));
        plugins = [];
        prs = [];
        plugins.push({
          name: 'removeDimensions'
        });
        prs.push(optimize(s, {plugins}));
        plugins.push({
          name: 'addClassesToSVGElement',
          params: {
            classNames: [name]
          }
        });
        plugins.push({
          name: 'removeXMLNS'
        });
        prs.push(optimize(s, {plugins}));
        return pr.all(prs).then(function([forCSS, forDOM]) {
          return {
            forCSS: forCSS.data,
            forDOM: forDOM.data
          };
        });
      }).catch(function(e) {
        return console.error(e.stack);
      });
    },
    html: function(s) {
      if (self.prod) {
        return htmlmin.minify(s);
      } else {
        return s;
      }
    },
    json: function(s) {
      return JSON.parse(s);
    },
    yml: function(s) {
      return yaml.load(s);
    }
  },
  // crawls the filesystem and always does one thing, and usually does a second:
  // 1. find all non-pug files to transform into pug variable (sync AND async)
  // 2. do the pug compilation, which CANNOT do async...unless you want set
  // `skipPug`, because you're just dumping info about what happened in stage
  // 1, for example
  crawl: function(rootDir, skipPug) {
    var head;
    self.vars.basedir = path.resolve(rootDir);
    execAsync(`cd '${self.vars.basedir}' && git rev-parse --short HEAD`).then((stdout) => {
      return self.vars.src.GIT_HEAD = stdout.toString().trim();
    }).catch(function() {
      return self.vars.src.GIT_HEAD = null;
    });
    if (head = self.vars.src.GIT_HEAD) {
      execAsync(`cd '${self.vars.basedir}' && git tag --points-at ${head}`).then((stdout) => {
        return self.vars.src.GIT_TAGS = stdout.toString().split('\n').filter(function(s) {
          return s.match(/\S/);
        });
      }).catch(function() {
        return self.vars.src.GIT_TAGS = [];
      });
    }
    return execAsync(`find '${self.vars.basedir}' -type f -print0`).then((stdout) => {
      var other_files, pug_files;
      pug_files = [];
      other_files = [];
      stdout.split('\0').forEach((f) => {
        var ext, name, srcname;
        if (!f) {
          return;
        }
        ({name, ext, srcname} = self.parsename(f));
        if (name.match(/^_/)) {
          log(`skip: ${f}`);
          return self.vars.src[srcname] = null;
        } else if (ext === 'pug') {
          pug_files.push(f);
          return self.vars.src[srcname] = null;
        } else if (self.exts[ext]) {
          return other_files.push(f);
        }
      });
      return pr.each(other_files, (f) => {
        var srcname;
        log('reading:', f);
        ({srcname} = self.parsename(f));
        return self.transform(f).then((out) => {
          return self.vars.src[srcname] = out;
        });
      }).then(() => {
        if (!skipPug) {
          return pr.each(pug_files, (f) => {
            var outfile, srcname;
            outfile = f.replace(/\.pug$/i, '.html');
            ({srcname} = self.parsename(outfile));
            return self.pug(f, srcname);
          });
        }
      });
    });
  },
  self: function(testPug) {
    return self.crawl(`${__dirname}/../src`, true).then(() => {
      if (testPug) {
        return self.crawl(`${__dirname}/../test`, false);
      }
    });
  }
};
