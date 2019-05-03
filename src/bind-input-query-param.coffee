# This is a small library to bind an HTML <input> (or anything with a .value
# attribute and .onkeyup event) to both:
#
#   - a query parameter in the page url
#   - a javascript function (optional)
#
# The query param binding is immediate, and the javascript function will be
# called when one of these occurs:
#
#   - the <input> value has changed (after waiting a debounce delay)
#   - the <input> receives an Enter keypress, then the binding fires immediately
#
# Example pug:
#
#   input#query
#   :inject(file="bind-input-query-param.coffee")
#   :inject(ext="coffee")
#     bindInputQueryParam '#query', ->
#       console.log 'the query was updated, look at the url!'

do ->
  params = new URLSearchParams(window.location.search)
  cache = {}
  cacheKey = (sel) -> btoa(sel)
  paramKey = (sel) -> sel.replace /[^\w-_\.]/g, ''

  window.bindInputQueryParam = (sel, fn, delay) ->
    # sets up everything to bind an element's value to a query param, and
    # optionally to a js function
    key = cacheKey(sel)
    if cache[key]
      throw new Error '.setup() called twice for selector:', sel
    if not document.querySelector(sel)
      throw new Error 'no element found for selector:', sel
    if fn and typeof fn isnt 'function'
      throw new Error "second argument must be a function instead of:", fn
    delay = if delay then +delay else 300

    cache[key] =
      val: document.querySelector(sel).value
      timer: null
      readParam: false

    document.querySelector(sel).onfocus = ->
      # set the input value from the query param, but only on first focus,
      # so that any "placeholder" attribute is still visible
      if not cache[key].readParam and params.has(paramKey(sel))
        cache[key].readParam = true
        val = params.get(paramKey(sel))
        if val isnt document.querySelector(sel).value
          document.querySelector(sel).value = val

    document.querySelector(sel).onkeyup = (e) ->
      val = document.querySelector(sel).value

      # update the query string all the time, and do it immediately
      if /\S/.test(val)
        params.set paramKey(sel), val
        query = "?#{params}"
      else
        params.delete paramKey(sel)
        size = 0
        size++ for p in params.keys()
        query = if size > 0 then "?#{params}" else ""
      window.history.replaceState({}, '', "#{window.location.pathname}#{query}")

      # depending on what key was pressed or whether the input value has changed,
      # we either fire the binding immediately or after a short debounce
      update = (ms) ->
        cache[key].val = val
        if fn
          clearTimeout(cache[key].timer) if cache[key].timer
          cache[key].timer = setTimeout fn, ms
      if e.key is 'Enter'
        update(0)
      else if val isnt cache[key].val
        update(delay)
