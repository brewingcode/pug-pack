# pug-pack

> Pseudo-webpack for developers who like clean formatting

```sh
npm install -g pug-pack
```

`pug-pack` compiles your `src` directory into your `dist` directory, with
assets (from both `pug-pack` and your own package) inlined into the resulting
`.html` files. Each `.html` file is entirely self-contained, in order to bring
network requests down to just one. Cleanly-formatted languages
([.pug](https://pugjs.org/api/getting-started.html),
[.coffee](http://coffeescript.org/), [.styl](http://stylus-lang.com/), and
[.yml](http://www.yaml.org/start.html)) are supported, but you can fall back
on files from the last 20 years if you need (or want) to.

You can compile a few test files with:

```sh
pug-pack "$(npm -g root)/pug-pack/test"
open dist/index.html
```

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

* (carefully) the `include` keyword combined with the `inject` filter (see
"What's wrong with `include`?", below)

See examples in [index.pug](test/index.pug) and [hyper.pug](test/hyper.pug).

**Note:** To `extend` a `.pug` template from `pug-pack` (such as `_base.pug`),
you need to use the full path to its location in your `node_modules`
directory. See the "What's wrong with `include`?" section for why.

```pug
extend ../node_modules/pug-pack/src/_base
```

# non-pug files

The following file types are supported: `.coffee`, `.styl`, `.yml`, `.js`,
`.css`, `.svg`, `.html`, and `.json`.

Most of these are simple transforms of text-to-text, but there are a few
that are converted into objects. These require a little care:

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
  each val,key in src["people.yml"]
    li #{val.name} lives in #{val.city} and their SSN is #{key}
```

### `.svg`

SVG files are more complicated, because they can either be inlined into a
`<style>` tag, or they can be used "raw", ie embeded straight into HTML as an
`<svg>` element.

```pug
// creates a "raw" <svg> element with a CSS class of "github-svg"
:inject(file="github.svg")

// creates a <style> element that declares the "github-svg" CSS class
:inject(file="github.svg" css)
```

Note the `css` attribute passed to the `:inject` filter: this is required to
tell the filter to produce CSS instead of SVG.

# CLI

This package comes with `pug-pack`, which will compile this package's files
first, and then compile your own `src` files. Any file naming collisions will
override the default files from this package, so if you have
`src/bootstrap.js`, that is the Bootstrap CSS that will be used.

You can override the `src` and `dist` directories, and pass other options:

```
usage:

pug-pack [src] [dist] [-p|--prod|--production] [-w|--watch]
  [-v|--verbose]

pug-pack [-l|--list] [-h|--help]

default: pug-pack ./src ./dist
```

The CLI is [here](lib/cli.coffee).

# API

You can `require('pug-pack')` yourself, if you really want to: see the
[CLI](lib/cli.coffee) for more.

# ignored files

Any files under `src` that begin with an underscore are ignored by the
compilation process. Some possible uses:

* `.pug` files that don't map to an `.html` file, for instance shared headers
  and footers

* re-useable modules (`.coffee`, `.styl`, or `.js`)

* misc scripts

# What's wrong with `include`?

Due to the way `pug-pack` does a two-pass build (once in its own `src`
directory, and again in _your_ `src` directory), `include:inject` has a
pitfall: you can only (easily) `include:inject` files that are present in
_your own_ `src` directory.

For example, to `include` Bootstrap from `pug-pack`, you might try:

```pug
include:inject bootstrap.css
```

However, because Pug defaults to finding your include files relative to the
`.pug` file itself, Pug will not find `bootstrap.css`, unless you happen to
have your own copy in your `src` directory. In order to `include` Bootstrap
from `pug-pack` you would need to use:

```pug
    style
      include:inject ../node_modules/pug-pack/src/bootstrap.css
```

As noted above, avoid this issue by simply using
`:inject(file="bootstrap.ss")`, without worrying about `include`. The filter
is smart enough to figure out where to look for files.
