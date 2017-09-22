# static-page

A poor man's webpack for lazy whitespace lovers

```
npm install -g https://github.com/brewingcode/static-page
static-page
```

The above will compile your `src` directory into your `dist` directory, with
assets (from both `static-page` and your own package) inlined into the
resulting `.html` files.

# pug

The main files in `src` are your `.pug` files: these will each end up in
the `dist` directory at the exact path they are at:

    src/index.pug       --> dist/index.html
    src/foo/bar/baz.pug --> dist/foo/bar/baz.html

Each `.pug` file is compiled with template variables generated from all the
_other_ non-pug files in the `src` directory, such as scripts, styles, and
images. These files are passed to Pug via:

* the `inject` filter

* the `src` template variable

* (carefully) the `include` keyword combined with the `inject` filter (see "What's
wrong with `include`?", below)

See examples in [index.pug](test/index.pug) and [hyper.pug](test/hyper.pug).

**Note:** To `extend` a `.pug` template from `static-page` (such as
`_base.pug`), you need to use the full path to its location in your `node_modules`
directory. See the "What's wrong with `include`?" section for why.

    extend ../node_modules/static-page/src/_base

# non-pug files

The following file types are supported: `.coffee`, `.styl`, `.yml`, `.js`,
`.css`, `.svg`, `.html`, and `.json`.

Most of these are simple transforms of text-to-text, but there are a few
that are converted into objects, which requires a little care:

### `.yml` and `.json`

These files are simply converted to objects, so that Pug's templating can use
them:

```yml
# people.yml
123:
  name: Spongebob Squarepants
  location: a pineapple under the sea
456:
  name: Elon Musk
  location: Ne Syrtis, Mars
```

```pug
// index.pug
ul
  each val,key in src["people.json"]
    li #{val.name} lives in #{val.city} and their SSN is #{key}
```

### `.svg`

SVG files are more complicated, because they can either be inlined into a
`<style>` tag, or they can be used "raw", ie embeded straight into HTML as an
`<svg>` element.

```
//- creates a "raw" <svg> element with a CSS class of "github-svg"
:inject(file="github.svg")

//- creates a <style> element that declares the "github-svg" CSS class
:inject(file="github.svg" css)
```

Note the `css` attribute passed to the `:inject` filter: this is required to
tell the filter to produce CSS instead of SVG.

# CLI

This package comes with `static-page`, which will compile this package's files
first, and then compile your own `src` files. Any file naming collisions will
override the default files from this package, so if you have
`src/bootstrap.js`, that is the Bootstrap CSS that will be used.

The CLI also includes `-p` to minify all files as much as possible, and `-w`
to use Nodemon to re-build your `dist` directory anytime any file in `src`
is modified. `-l` is for listing all the files involved, and `-v` is for
verbose output.

The CLI is [here](lib/cli.coffee).

# ignored files

Any files under `src` that begin with an underscore are ignored by the
compilation process. Some possible uses:

* `.pug` files that don't map to an `.html` file, for instance shared headers
  and footers

* re-useable modules (`.coffee`, `.styl`, or `.js`)

* misc scripts

# What's wrong with `include`?

Due to the way `static-page` does a two-pass build (once in its own `src`
directory, and again in _your_ `src` directory), `include:inject` has a
pitfall: you can only (easily) `include:inject` files that are present in
_your own_ `src` directory.

For example, to `include` Bootstrap from `static-page`, you might try:

    include:inject bootstrap.css

However, because Pug defaults to finding your include files relative to the
`.pug` file itself, Pug will not find `bootstrap.css`, unless you happen to
have your own copy in your `src` directory. In order to `include` Bootstrap
from `static-page` you would need to use:

    style
      include:inject ../node_modules/static-page/src/bootstrap.css

As noted above, avoid this issue by simply using
`:inject(file="bootstrap.ss")`, without worrying about `include`. The filter
is smart enough to figure out where to look for files.
