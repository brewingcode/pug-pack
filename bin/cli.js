#!/usr/bin/env node
//!/usr/bin/env coffee
var argv, browserSync, build, fs, fullBuild, mkdirp, path, pkg, pr, src,
  indexOf = [].indexOf;

build = require('./build');

browserSync = require('browser-sync');

fs = require('fs');

path = require('path');

mkdirp = require('mkdirp');

argv = require('minimist')(process.argv.slice(2), {
  boolean: ['p', 'prod', 'production', 'w', 'watch', 'v', 'verbose', 'V', 'version', 'init', 'i', 'clean', 'c']
});

pr = require('bluebird');

if (argv.h || argv.help) {
  console.log(`usage:

pug-pack [src] [dist] [-p|--prod|--production] [-w|--watch]
  [-v|--verbose] [-c|--clean]

pug-pack [-l|--list] [-i|--init] [-h|--help] [-V|--version]

default: pug-pack ./src ./dist`);
  process.exit();
}

if (argv.V || argv.version) {
  pkg = require('../package.json');
  console.log(pkg.version);
  process.exit();
}

if (argv.p || argv.prod || argv.production) {
  build.prod = true;
}

if (argv.v || argv.verbose) {
  build.verbose = true;
}

src = argv._.length > 0 ? argv._[0] : './src';

build.dist = argv._.length > 1 ? argv._[1] : './dist';

if (argv.c || argv.clean) {
  try {
    fs.rmSync(build.dist, {
      recursive: true,
      force: true
    });
  } catch (error) {}
}

fullBuild = function() {
  return build.self().then(function() {
    return build.crawl(src);
  });
};

pr.try(function() {
  var touched, update;
  if (argv.w || argv.watch) {
    return fullBuild().then(function() {
      var bs;
      bs = browserSync.create();
      bs.watch(src + '/**/*', null, function(e) {
        if (e === 'change') {
          build.vars.src = {};
          return fullBuild().then(function() {
            return bs.reload();
          });
        }
      });
      return bs.init({
        server: build.dist,
        host: process.env.HOST || '127.0.0.1',
        port: process.env.PORT || 3000,
        ghostMode: false,
        logConnections: true,
        logFileChanges: true
      });
    });
  } else if (argv.l || argv.list) {
    return build.self().then(function() {
      var baseAssets, i, k, len;
      console.log('## assets from pug-pack');
      baseAssets = Object.keys(build.vars.src);
      for (i = 0, len = baseAssets.length; i < len; i++) {
        k = baseAssets[i];
        console.log(k, build.vars.files[k]);
      }
      return build.crawl(src, true).then(function() {
        console.log('## assets from you');
        return Object.keys(build.vars.src).filter(function(x) {
          return indexOf.call(baseAssets, x) < 0;
        }).forEach(function(x) {
          return console.log(x, build.vars.files[x]);
        });
      });
    });
  } else if (argv.i || argv.init) {
    if (fs.existsSync('./package.json')) {
      pkg = JSON.parse(fs.readFileSync('./package.json'));
      touched = 0;
      update = function(name, cmd) {
        if (pkg.scripts == null) {
          pkg.scripts = {};
        }
        if (pkg.scripts[name]) {
          console.warn(`'${name}' run-script already exists`);
          return 0;
        } else {
          pkg.scripts[name] = cmd;
          return 1;
        }
      };
      touched += update('dev', 'pug-pack --watch');
      touched += update('build', 'pug-pack --production');
      if (touched > 0) {
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, '  '));
        console.log('package.json updated with "dev" and/or "build" run-scripts');
      }
    } else {
      console.warn('no package.json file found, run-scripts not written');
    }
    if (!fs.existsSync(src)) {
      console.log("creating 'src' directory");
      mkdirp.sync(src);
    }
    if (fs.existsSync(`${src}/base.pug`)) {
      console.warn(`${src}/_base.pug already exists, not modifying it`);
    } else {
      console.log("writing 'src/_base.pug' as an example default layout");
      fs.copyFileSync(`${__dirname}/../src/_base.pug`, `${src}/_base.pug`);
    }
    if (fs.existsSync(`${src}/index.pug`)) {
      console.warn(`${src}/index.pug already exists, not modifying it`);
    } else {
      console.log("writing 'src/index.pug' as an example index file");
      fs.writeFileSync(`${src}/index.pug`, `extends _base
append head
  :inject(file="bootstrap.css")
append body
  .container-fluid
    p Hello from pug-pack and Bootstrap`);
    }
    return console.log("run 'pug-pack -w' to build and view the example index file in 'dist/index.html'");
  } else {
    return fullBuild();
  }
}).catch(function(e) {
  console.error(e);
  return process.exit(1);
});
