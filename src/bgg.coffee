
dataVersion = 3
load = ->
  if data = localStorage.getItem('bgg')
    data = JSON.parse(data)
    return data if data.version is dataVersion
  return {}
save = ->
  data = JSON.stringify
    username: app.username
    selected: app.selected
    gameFilter: app.gameFilter
    playerFilter: app.playerFilter
    version: dataVersion
  localStorage.setItem('bgg', data)

getUser = _.debounce ->
  app.isLoading = true
  app.controller = new AbortController()
  fetch "https://do.brewingcode.net:2083/bgg/#{app.username.trim()}",
    signal: app.controller.signal
  .then (resp) ->
    resp.json()
  .then (json) ->
    if json.error
      app.usernameErrors = [ "Error getting user: #{json.error}" ]
    else if json.play
      app.plays = json.play
      saved = load()
      if saved.username is app.username
        app.selected = saved.selected
        app.gameFilter = saved.gameFilter
        app.playerFilter = saved.playerFilter
      else
        app.selected = []
        app.gameFilter = ''
        app.playerFilter = ''
    else
      app.usernameErrors = [ 'No games found for that user' ]
      app.plays = []
  .catch (e) ->
    if e.name is 'AbortError'
      return
    console.error e
    app.usernameErrors = [ "Unknown error: #{e.message}" ]
  .finally ->
    app.isLoading = false
    app.controller = null
    if app.usernameErrors.length > 0
      app.$nextTick(app.$refs.u.focus)
, 500

app = new Vue
  el: '#app'
  template:'#app'
  vuetify: new Vuetify()

  data: ->
    saved = load()
    headers:
      players: [
        { text: 'Player Name', value: 'name' }
        {
          text: 'Number of Games Played'
          value: 'count'
          filter: (v) =>
            if @playerFilter
              +v >= +@playerFilter
            else
              true
        }
      ]
      games: [
        {
          text: 'Game'
          value: 'name'
          filter: (v) =>
            if @gameFilter
              v.toLowerCase().includes(@gameFilter.toLowerCase())
            else
              true
        }
        { text: 'Date', value: 'date' }
        { text: 'Players', value: 'players' }
        { text: 'Location', value: 'location'}
      ]
    plays: []
    selected: saved.selected or []
    gameFilter: saved.gameFilter or ''
    playerFilter: saved.playerFilter or ''
    username: ''
    usernameErrors: []
    isLoading: false
    controller: null

  mounted: ->
    bindInputQueryParam '#u', null, null, (v) =>
      if v
        @username = v
      else
        saved = load()
        @username = saved.username

  watch:
    selected: -> save()
    gameFilter: -> save()
    playerFilter: -> save()
    username: (v) ->
      @usernameErrors = []
      if @username and @username.match(/\S/)
        @controller.abort() if @controller
        @plays = []
        getUser()

  methods:
    commify: (s) -> s.toString().replace /// \B (?= (\d{3})+ (?!\d) ) ///g, ','

  computed:
    players: ->
      names = {}
      @plays.forEach (play) ->
        addName = (player) ->
          names[player.name] ?= []
          names[player.name].push play.id
        if Array.isArray(play.players)
          play.players.forEach addName
        else if play.players?.player
          addName play.players.player
        else
          addName name:'(no players)'

      return _(names)
        .keys()
        .map (k) ->
          name: k
          plays: names[k]
          count: names[k].length
        .sortBy (p) ->
          +p.count
        .reverse()
        .value()

    commonPlays: ->
      ids = _.intersection ...@selected.map (player) -> player.plays
      @plays.filter (play) -> play.id in ids

    commonGames: ->
      @commonPlays.map (play) ->
        players = _(play.players)
          .map (p) -> p.name
          .sortBy (p) -> p.toLowerCase()
          .join '<br>'

        return
          name: play.item.name
          gameid: play.item.objectid
          playid: play.id
          date: play.date
          players: players
          location: play.location

    stats: ->
      games = @commonPlays
      if @gameFilter
        games = games.filter (g) => g.item.name.toLowerCase().includes(@gameFilter.toLowerCase())

      stats =
        'Number of games': games.length

      winners = {}
      selected = @selected.map (x) -> x.name
      games.forEach (play) ->
        if Array.isArray(play.players)
          play.players.forEach (player) ->
            if player.name in selected
              winners[player.name] ?= 0
              winners[player.name]++ if +player.win is 1

      _(winners)
        .keys()
        .map (k) =>
          name: k
          count: winners[k]
          pct: Math.floor(winners[k]/games.length*100)
        .sortBy (w) -> +w.count
        .reverse()
        .each (w) ->
          stats["#{w.name} wins"] = w.count + ' (' + w.pct + '%)'

      return stats
