# https://boardgamegeek.com/wiki/page/BGG_XML_API2

pr = require 'bluebird'
{ execSync, execAsync } = pr.promisifyAll require 'child_process'
fs = require 'fs'
mkdirp = require 'mkdirp'

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
    return n

parseResponse = (resp) ->
  new pr (resolve) ->
    try
      json = execSync('xq .', { input:resp })
      resolve fixXml JSON.parse(json)
    catch e
      f = '/tmp/failed-bgg-parse.txt'
      fs.writeFileSync(f, resp)
      console.error "unable to parse api response (see #{f}):", e
      resolve null

onePage = (username, page) ->
  url = "https://www.boardgamegeek.com/xmlapi2/plays?username=#{username}&page=#{page or 1}"
  await parseResponse await execAsync("curl -qsS '#{url}'")

oneThing = (id) ->
  url = "https://www.boardgamegeek.com/xmlapi2/thing?id=#{id}"
  await parseResponse execAsync("curl -qsS '#{url}'")

allPlays = (username) ->
  first = await onePage(username)
  if not first or first.div?.class is 'messagebox error'
    return
      plays:
        play = []
      error: first.div['#text']
  totalpages = Math.floor(+first.plays.total / 100) + 1
  if totalpages > 1
    prs = await pr.all [2 .. totalpages].map (page) ->
      await onePage(username, page)
    prs.forEach (page, i) ->
      if not page.plays?.play
        console.error "no plays on page #{i}"
      else
        first.plays.play.push ...page.plays.play
  delete first.page
  return first

module.exports = { fixXml, onePage, allPlays, oneThing }

unless module.parent
  [ username ] = process.argv.slice(2)
  unless username
    console.error "username required"
    process.exit(1)
  do -> console.log JSON.stringify await allPlays(username)
