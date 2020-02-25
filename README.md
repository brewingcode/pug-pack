# pug-pack

> Static site generator for developers who like clean formatting, plus a handful
of CLI tools using Pug and/or CoffeeScript.

```sh
npm install -g pug-pack
pug-pack --init
```

`pug-pack` takes all the `.pug` templates in your `src` directory, and renders
each one as an `.html` file in a `dist` directory. A custom `:inject()` filter
allows you to easily inline other assets (scripts, CSS, images) into the
`.html` files. Cleanly-formatted languages
([.pug](https://pugjs.org/api/getting-started.html),
[.coffee](http://coffeescript.org/), [.styl](http://stylus-lang.com/), and
[.yml](http://www.yaml.org/start.html)) are supported, but you can fall back
on files from the last 20 years if you have to.

You can see some examples by compiling the `test` directory of this repo:

```sh
cd pug-pack
npx pug-pack -w test
open dist/index.html
```

There are a couple other examples:

```
open dist/hyper.html
open dist/vue-chart.html
open dist/bgg.html
```

# Pug files

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

# Non-pug files

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

### extras

The `src` object also gets two additional properties:

* `GIT_HEAD`: the short git sha of the `src` HEAD

* `GIT_TAGS`: any tags that refer to `GIT_HEAD`

# Options for `pug-pack`

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

# Node API for `pug-pack`

You can `require('pug-pack')` yourself, if you really want to. The two main
methods are:

* `.self()` will process the assets in `pug-pack`'s own `src` directory (there
are no public `.pug` files in this directory, only .pug files prefixed with `_`
to denote they are skipped for compilation to .html)

* `.crawl(rootDir)` will process the assets in `rootDir`, which should include
one or more `.pug` files

See the [CLI](lib/cli.coffee) as an example.

# `include` and `extend` keywords in Pug

If you would rather use these pug built-ins, see `pugs` below: it exposes the
`pug-pack/src` directory via pug's own `--basedir` option, so that you can
write:

```pug
extend /_base  <!-- NOTE: the leading slash tells pug to use "absolute" paths,
               starting at --basedir -->

append head
  title Your Cool Page
```

If you don't want to use `pugs`, just specify the full path to `pug-pack/src`
when you use `include` and `extend`.

# Additional JSTransformers included in `pug-pack`

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

- `pug` itself might include the `coffee-script` filter, which is CoffeeScript v1

- this jstransformer is `coffeescript` (without the hyphen), and is CoffeeScript v2

- syntax hightlighting doesn't play well with the custom `:inject` filter,
  so for inlining more than a few lines of CoffeeScript, this jstransformer
  is preferable

### markdown-it

Markdown and Pug are a great combo, use this filter like so:

```pug
:markdown-it
    # Your Markdown Content

    | Column A         | Column B             |
    | ---------------- | -------------------- |
    | A little of this |                      |
    |                  | and a little of that |
```

# Reference for files in `src`


## Third-party libraries

| File(s)                          | Notes                                                                 |
| -------------------------------- | --------------------------------------------------------------------- |
| bootstrap.css                    | Bootstrap CSS                                                         |
| chart.js + chart.css             | Chart.js for making charts                                            |
| filesize.js                      | Convert numbers to SI-prefixed byte strings                           |
| hyperapp.js                      | HyperApp UI Framework                                                 |
| jquery-stripped.js               | Custom JQuery build                                                   |
| jquery.js                        | Standard JQuery library                                               |
| jquery.tablesorter.min.js        | Plugin to turn any table sortable                                     |
| tablesorter-theme-bootstrap4.css | Nice CSS for the tablsorter plugin                                    |
| lodash-custom.js                 | Custom Lodash build                                                   |
| lodash.js                        | Standard Lodash build                                                 |
| md-icons.css                     | Local copy of Material Design css                                     |
| moment.js                        | Moment.js                                                             |
| moment-timezone.js               | Timezone data for Moment                                              |
| showdown.js                      | Showdown.js to render Markdown to HTML on the client                  |
| sorttable.js                     | An ancient way to make table sortable; use JQuery.tablesorter instead |
| vue-dev.js                       | Vue.js dev build                                                      |
| vue-prod.js                      | Vue.js prod build                                                     |
| vuetify.js                       | Vuetify UI Framework                                                  |
| vuetify.css                      | CSS for Vuetify                                                       |

## Example Pug files

| Template      | Notes                                                                          |
| ------------- | ------------------------------------------------------------------------------ |
| vue-chart.pug | Demo for using Vuetify inside pug-pack that graphs/aggregates time-series data | 
| bgg.pug       | Small Docker-based site to view BoardGameGeek data                             |

## Client-side helpers

| File                           | Notes                                                                     |
| ------------------------------ | ------------------------------------------------------------------------- |
| bind-input-query-param.coffee  | Easily wrangle query params in the url (see below)                        |
| mdtable.js                     | Convert JS array-of-arrays to a string of nicely-formatted Markdown table |
| commify.js                     | Inject commas as thousands separators to a number                         |

### bind-input-query-param.coffee

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

# Misc CLI Tools

## tsc

This is a command-line tool to feed newline-based timestamps into
vue-chart.pug on your local machine.

```
tsc - (t)ime (s)eries (c)hart

usage: tsc [file ...] [-f fmt>]

Parse timestamps from lines of input and graph it using Vue and Chart.js. The
chart includes:

- aggregation by adjustable duration
- limiting to most recent timestamps

Each timestamp has a weight of 1, so that default aggregation amounts to simply
counting timestamps. Weight can be changed by including a number with each
timestamp, either before or after the timestamp and separated by comma or tab,
for example:

    2019-08-29,12
    24,2019-08-30
    26,2019-09-01

Timestamps are parsed strictly.

-f/--format <moment format string>

    Without a format, falls back on moment's default parsing, otherwise
    parsing will use your format:

    https://momentjs.com/docs/#/parsing/string/
    https://momentjs.com/docs/#/parsing/string-format/
```

## cs

A CLI that wraps the `coffee` script with some useful behavior for shell
one-liners, as well as exploring CoffeeScript in its REPL.

```
Run CoffeeScript with lots of pre-defined objects/functions:

  s: sugar.js
  m: moment.js
  l: lodash.js
  fs: fs
  log: console.log()
  js: JSON.stringify()
  jp: JSON.parse()
  fsr: fs.readFileSync()
  fsw: fs.writeFileSync()

If given args, assumes each arg is a line of the function to run on each
line of stdin. Without args, just opens the REPL.
```

## pugs

A CLI to run `pug` in the context of your local pug-pack installation. `src`
in this context is the `pug-pack/src` directory itself, not your own `src`
directory.

```
$ pugs -h
A wrapper around running pug with --basedir set to pug-pack's `src` directory.

usage:
  pugs [-l|--list|ls [ARGS]]   # runs `ls` with ARGS in `src`
  pugs [-f|--find|find [ARGS]] # runs `find` with ARGS in `src`
  pugs ARGS                    # runs `pug` with --basedir set to `src` and
                               # ARGS for pug
```
