
```
/*
 * jQuery throttle / debounce - v1.1 - 3/7/2010
 * http://benalman.com/projects/jquery-throttle-debounce-plugin/
 *
 * Copyright (c) 2010 "Cowboy" Ben Alman
 * Dual licensed under the MIT and GPL licenses.
 * http://benalman.com/about/license/
 */
(function(b,c){$.throttle=a=function(e,f,j,i){var h,d=0;if(typeof f!=="boolean"){i=j;j=f;f=c}function g(){var o=this,m=+new Date()-d,n=arguments;function l(){d=+new Date();j.apply(o,n)}function k(){h=c}if(i&&!h){l()}h&&clearTimeout(h);if(i===c&&m>e){l()}else{if(f!==true){h=setTimeout(i?k:l,i===c?e-m:e)}}}if($.guid){g.guid=j.guid=j.guid||$.guid++}return g};$.debounce=function(d,e,f){return f===c?a(d,e,false):a(d,f,e!==false)}})(this);
```

id = 'a368f23f8175'
history = {}
showing = false

show = ->
  $('body').append """
    <div id="#{id}" style="position:fixed;top:0;z-index:9999999999;">
      <a href="#">[x]</a>
      <span>&nbsp;</span>
      <input type="text" placeholder="selector" value="tr"/>
      <input type="text" placeholder="regex"/>
    </div>
  """
  showing = true

  $('input[placeholder="regex"]').focus()

  $("##{id} input").on 'input', $.debounce 250, ->
    sel = $('input[placeholder="selector"]').val()
    q = $('input[placeholder="regex"]').val()
    if sel
      $(sel).each ->
        if q
          if $(this).text().match new RegExp(q, 'i')
            $(this).css 'display', ''
          else
            $(this).css 'display', 'none'
            history[sel] = [] unless history[sel]
            history[sel].push this
        else
          $(this).css 'display', ''
    else
      for own sel, elements of history
        for el in elements
          $(el).css 'display', ''
        delete history[sel]

  $("##{id} a").on 'click', ->
    $(this).parent().remove()
    return false

hide = ->
  $("##{id}").remove()
  showing = false

show()
