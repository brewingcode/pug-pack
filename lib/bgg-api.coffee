# https://boardgamegeek.com/wiki/page/BGG_XML_API2

{ execSync } = require 'child_process'
fs = require 'fs'

fixXml = (n) ->
  log = -> 0 # console.log
  if Array.isArray(n)
    log 'array:', n.length
    return n.map fixXml
  else if typeof n is 'object'
    log 'object:', Object.keys(n)
    for k,v of n
      if m = k.match /^@(.*)/
        log 'renaming', k, 'to', m[1]
        delete n[k]
        k = m[1]
        n[k] = v
      if m = k.match /(.*)s$/
        if Array.isArray(v[m[1]]) and Object.keys(v).length is 1
          log 'restructuring lonely array'
          n[k] = v[m[1]]
      n[k] = fixXml n[k]
    return n
  else
    log 'scalar:', n
    x = parseFloat(n)
    return if isNaN(x) then n else x

onePage = (username, page) ->
  url = "https://www.boardgamegeek.com/xmlapi2/plays?username=#{username}&page=#{page or 1}"
  resp = execSync("curl -qsS '#{url}'")
  try
    json = execSync('xq .', { input:resp })
    fixXml JSON.parse(json)
  catch e
    f = '/tmp/failed-bgg-parse.txt'
    fs.writeFileSync(f, resp)
    console.error "unable to parse api response (see #{f}):", e
    process.exit(2)

allPlays = (username) ->
  first = onePage(username)
  totalpages = Math.floor(+first.plays.total / 100) + 1
  if totalpages > 1
    [2 .. totalpages].forEach (page) ->
      first.plays.play.push ...onePage(username, page).plays.play
  delete first.page
  return first

module.exports = { fixXml, onePage, allPlays }

unless module.parent
  [ username ] = process.argv.slice(2)
  unless username
    console.error "username required"
    process.exit(1)
  console.log JSON.stringify allPlays(username)
