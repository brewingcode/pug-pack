# https://boardgamegeek.com/wiki/page/BGG_XML_API2

pr = require 'bluebird'
{ execSync, execAsync } = pr.promisifyAll require 'child_process'
fs = require 'fs'
mkdirp = require 'mkdirp'
knex = require 'knex'
moment = require 'moment'
log = require('debug')('bgg')

datadir = '/tmp/bgg'

dbh = null
db = (args...) -> if args.length then dbh(args...) else dbh
do ->
  dbh = await knex
    client: 'sqlite3'
    connection:
      filename: "#{datadir}/db.sqlite"
    useNullAsDefault: true

  makeTable = (t, cols) ->
    dbh.schema.hasTable('users').then (t) ->
      if not t
        dbh.schema.createTable 'users', (t) -> cols(t)
  await makeTable 'users', (t) ->
    t.string('bgg_name').notNullable().unique()
    t.json 'all_plays'
    t.timestamps true, true

fixXml = (n) ->
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

fetchUrl = (url) ->
  new pr (resolve) ->
    log "fetchUrl:", url
    resp = await execAsync("curl -qsS '#{url}'")
    try
      json = execSync('xq .', { input:resp })
      resp = fixXml JSON.parse(json)
      if resp.div?.class is 'messagebox error'
        console.error "api error:", url, resp.div['#text']
      resolve resp

    catch e
      f = "/tmp/failed-bgg-parse-#{moment().valueOf()}"
      fs.writeFileSync(f, resp)
      console.error "response parse failure (see #{f}):", e
      throw e

onePage = (username, page) ->
  (await fetchUrl "https://www.boardgamegeek.com/xmlapi2/plays?username=#{username}&page=#{page or 1}").plays

oneThing = (id) ->
  (await fetchUrl "https://www.boardgamegeek.com/xmlapi2/thing?id=#{id}").items

allPlays = (username) ->
  first = await onePage(username)
  if not first.play
    return
      error: first.div['#text']
  totalpages = Math.floor(+first.total / 100) + 1
  if totalpages > 1
    prs = await pr.all [2 .. totalpages].map (page) ->
      await onePage(username, page)
    prs.forEach (page, i) ->
      if not page.play
        console.error "no plays on page #{i}"
      else
        first.play.push ...page.play
  delete first.page
  return first

cachedPlays = (username, age) ->
  age ?= 60
  log "cachedPlays:", username, age

  rows = await db('users').select().where(bgg_name:username)
  if rows.length is 1
    if moment.utc(rows[0].updated_at).isBefore(moment().subtract(age, 'minutes'))
      log 'stale row'
      plays = await allPlays(username)
      await db('users').where
        bgg_name:username
      .update
        all_plays:JSON.stringify(plays)
    else
      log 'fresh row'
      plays = JSON.parse(rows[0].all_plays)
  else
    log 'no row'
    plays = await allPlays(username)
    await db('users').insert
      all_plays:JSON.stringify(plays)
      bgg_name:username

  return plays

module.exports = { fixXml, onePage, allPlays, oneThing, db, cachedPlays }

unless module.parent
  [ username, age ] = process.argv.slice(2)
  unless username
    console.error "username required"
    process.exit(1)
  pr.delay(300).then ->
    plays = await cachedPlays username, if age then +age else null
    console.log "#{plays.total} plays found"
  .finally ->
    db()?.destroy()
