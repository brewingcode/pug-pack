express = require 'express'
bgg = require './bgg-api'
sanitize = require 'sanitize-filename'
fs = require 'fs'

app = express()

port = process.env.PORT or 5000
host = process.env.HOST or '127.0.0.1'

app.get '/bgg/:username', (req, res) ->
  filename = sanitize(req.params.username)
  throw new Error "invalid username" unless filename
  filename = "/tmp/#{filename}.json"

  if fs.existsSync(filename) and not req.query.force
    res.send fs.readFileSync(filename)
  else
    data = bgg.allPlays(req.params.username)
    fs.writeFileSync(filename, JSON.stringify(data))
    res.json data

app.listen port, host, ->
  console.log "listening on #{host}:#{port}"
