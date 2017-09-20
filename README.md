# static-page

A poor man's webpack for lazy whitespace lovers

# pug

The main files in `src` are your `.pug` files: these will each end up in
the `dist` directory at the exact path they are at:

    src/index.pug       --> dist/index.html
    src/foo/bar/baz.pug --> dist/foo/bar/baz.html

Each `.pug` file is compiled with template variables generated from all
the _other_ files in the `src` directory, such as scripts, styles, and
images.

**NOTE:** Any files under `src` that begin with an underscore are
ignored by this compilation process.

# non-pug files

ALl non-pug files are either passed through (if they are plain HTML,
JavaScript, etc), or they are compiled down to their "plain" versions
(CoffeeScript to JavaScript, Stylus to CSS, etc). The files are then exposed
to pug as a single large object, organized by names and extensions:

    src/main.coffee
    src/custom.styl
    src/bootstrap.css
    src/moment.js
    src/jquery.js
    src/data.yml

The above files would be parsed into an object like so:

    {
      "coffee": {
        "main": "/* some javascript compiled by coffee-script */"
      },
      "styl": {
        "custom": "/* some css compiled by stylus */"
      },
      "css": {
        "bootstrap": "/* bootstrap's css */"
      },
      "js": {
        "moment": "/* moment's js */",
        "jquery": "/* jquery's js */"
      },
      "yml": {
        "data": {
          "some": ["more", "complicated", "data", "of", "your", "own"],
          "answer": 42
        }
      }
    }

This object is then passed to Pug's `render()` function, so that you can
inject whichever files you choose into your final `.html` file(s). See the
example files:

* [index.pug](src/index.pug)
* [hyper.pug](src/hyper.pug)

The following file types are supported: `.js`, `.coffee`, `.css`, `.styl`,
`.svg`, `.html`, `.json`, `.yml`.

# CLI

This package comes with `static-page`, which will compile this package's files
first, and then add/override the pug template object with _your_ `src` files.
Note that this package's `.pug` files are _not_ included when `static-page` is
called, because you wouldn't want the demo `index.html` and `hyper.html` files
in your `dist` directory.

The CLI also includes `-p` to minify all files as much as possible, and `-w`
to use Nodemon to re-build your `dist` directory anytime any file in `src`
is modified.

See [the CLI script](src/_cli.coffee) for more.
