express = require 'express'
bgg = require './bgg-api'
sanitize = require 'sanitize-filename'
fs = require 'fs'
cors = require 'cors'
morgan = require 'morgan'

app = express()

port = process.env.PORT or 5000
host = process.env.HOST or '127.0.0.1'

app.use cors()
app.use morgan('dev')

app.get '/:username', (req, res) ->
  res.json await bgg.cachedPlays req.params.username

app.listen port, host, ->
  console.log "listening on #{host}:#{port}"
