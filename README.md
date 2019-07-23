# pug-pack

> Static site generator for developers who like clean formatting

```sh
yarn add pug-pack
mkdir -p src
cat <<EOF > src/index.pug
extends ../node_modules/pug-pack/src/_base

append head
  :inject(file="bootstrap.css")

append body
  .container
    p Hello from pug-pack and Bootstrap
EOF
npx pug-pack
open dist/index.html
```

`pug-pack` takes all the `.pug` templates in your `src` directory, and renders
each one as an `.html` file in a `dist` directory. A custom `:inject()` filter
allows you to easily inline other assets (scripts, CSS, images) into the
`.html` files. Cleanly-formatted languages
([.pug](https://pugjs.org/api/getting-started.html),
[.coffee](http://coffeescript.org/), [.styl](http://stylus-lang.com/), and
[.yml](http://www.yaml.org/start.html)) are supported, but you can fall back
on files from the last 20 years if you have to.

You can compile a few test files with:

```sh
pug-pack "$(npm -g root)/pug-pack/test"
open dist/index.html
```

# pug

The main files in `src` are your `.pug` files: these will each end up in
the `dist` directory at the exact path they are at, relative to `src`:

    src/index.pug       --> dist/index.html
    src/foo/bar/baz.pug --> dist/foo/bar/baz.html

Each `.pug` file is compiled with content generated from all the _other_
non-pug asset files in the `src` directory, such as scripts, styles, and
images. These assets are included in Pug templates via:

* custom `:inject()` filter

* `src` template variable

See [`non-pug files`](#non-pug-files) for more details, or some examples in
[test/index.pug](test/index.pug) and [test/hyper.pug](test/hyper.pug). The
`:inject()` filter is the main workhorse, and it can either:

* read an asset file and inline it as an HTML element

* transform inlined content in the template into plain HTML content

* injected content can be asyncronously generated, which is not possible with
standard `pug`

```pug
html
  head
    // this will create a <style> tag with Bootstrap's CSS
    :inject(file="bootstrap.css")

    // this will also create a <style> tag, but with the inline Stylus
    // transpiled to CSS
    :inject(ext="styl")
      .current-time
        color: red

  body
    .container-fluid
      p The current time is
        span.current-time

    // this will create a <script> tag with JQuery's code
    :inject(file="jquery.js")

    // and another <script> with Moment.js's code
    :inject(file="moment.js")

    // one more <script>, transpiled with CoffeeScript into plain JavaScript
    :inject(ext="coffee")
      $('.current-time').text moment()
```

# non-pug files

The following file types are supported: `.coffee`, `.styl`, `.yml`, `.js`,
`.css`, `.svg`, `.html`, and `.json`. Most of these are simple transforms of
text-to-text:

```pug
:inject(file="jquery.js")
:inject(ext="coffee")
  $('body').text "Hello from CoffeeScript, it is #{new Date()}"
```

However, some of these file types are converted into objects. These require a
little care:

### `.yml` and `.json`

These files are simply converted to objects, which you can use via the `src`
template variable in your Pug templates. Each file is accessed via it's
relative path from the `src` directory:

```yml
# src/people.yml
123:
  name: Spongebob Squarepants
  location: a pineapple under the sea
456:
  name: Elon Musk
  location: Ne Syrtis, Mars
```

```pug
// src/index.pug
ul
  each val,key in src["people.yml"]
    li #{val.name} lives in #{val.city} and their SSN is #{key}
```

Note that `src` also has _all_ the asset files, not just the `.yml` and
`.json` files. You can use Pug's `!{...}` interpolation to include these
assets directly, if you have a good reason to. For example, you declare the
data in a `.yml` file as a client-side JavaScript variable and use it:

```pug
:inject(file="jquery.js")
script.
  var people = !{JSON.stringify(src['people.yml'])};
  Object.keys(people).forEach(function(ssn) {
    var name = people[ssn].name;
    var city = people[ssn].city;
    $('ul').append('<li>' + city + ' is where ' + name + 'lives!</li>');
  });
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
tell the filter to produce CSS instead of SVG. See
[test/index.pug](test/index.pug) to see both uses of `:inject()` with an
`.svg` file.

# CLI

`pug-pack` will compile the assets in its own `src` directory first, and then
compile your own `src` files. Any file naming collisions will override the
files from `pug-pack` in favor of your version, so if you have
`src/bootstrap.css`, that is the Bootstrap CSS that will be used.

You can override the `src` and `dist` directories, and/or pass other options,
such as:

* `--production`/`-p` will minify everything as much as possible

* `--watch`/`w` will use `browser-sync` to watch `src` and re-run your build
on every change

* `--verbose`/`-v` for more verbose output

* `--list`/`-l` will list all files involved in the build

* `--init`/`-i` will initialize `pug-pack` in the current directory:

  - add a "dev" and "build" run-script to package.json

  - write a bare-bones `src/index.pug` file, as per the quickstart above

See `pug-pack --help` for more, or see the CLI [here](lib/cli.coffee).

# API

You can `require('pug-pack')` yourself, if you really want to. The two main
methods are:

* `.self()` will process the assets in `pug-pack`'s own `src` directory (there
are no public `.pug` files in this directory, only .pug files prefixed with `_`
to denote they are skipped for compilation to .html)

* `.crawl(rootDir)` will process the assets in `rootDir`, which should include
one or more `.pug` files

See the [CLI](lib/cli.coffee) as an example.

# `include` and `extend`

**tl;dr** Use `:inject(file=...)` instead of `include`, and be careful when
using `extend` with .pug files outside your `src` directory.

Because these two keywords read files before the `:inject()` filter can look
them up, you need to be very explicit when using these keywords to get assets
from `pug-pack` itself.

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

For `extend`, you will have to use the full relative path to `pug-pack/src`:

```pug
extend ../node_modules/pug-pack/src/_base
```

# Additional JSTransformers in Pug

### coffeescript

`pug-pack` includes a [CoffeeScript v2 jstransformer](https://github.com/zdenko/jstransformer-coffeescript),
which can be used in .pug as follows:

```
script
  :coffeescript(bare=true)
    foo = -> "this is foo"

script.
  console.log("foo says:", foo());
```

Note that:

- this is simply an alternative to `:inject(ext="cofffee")`

- `pug` itself comes with the `coffee-script` filter, which is CoffeeScript v1

- this jstransformer is `coffeescript` (without the hyphen), and is CoffeeScript v2

- syntax hightlighting doesn't play well with the custom `:inject` filter,
  so for inlining more than a few lines of CoffeeScript, this jstransformer
  is preferable

# helpers

## bind-input-query-param

[This](./src/bind-input-query-params.coffee) is a function to bind \<input>
elements to url query params, with a few extra conveniences around that. After
`:inject`ing it, simply call `bindInputQueryParam('#your-element-id')`, eg:

```pug
input#query
:inject(file="bind-input-query-param.coffee")
:inject(ext="coffee")
  bindInputQueryParam '#query', ->
    console.log 'the url query string was updated, look at it!'
```
