commify = (s) -> s.toString().replace /// \B (?= (\d{3})+ (?!\d) ) ///g, ','

dataVersion = 1
load = ->
  if data = localStorage.getItem('bgg')
    data = JSON.parse(data)
    return data if data.version is dataVersion
  return {}
save = ->
  data = JSON.stringify
    plays: app.plays
    selected: app.selected
    gameFilter: app.gameFilter
    version: dataVersion
  localStorage.setItem('bgg', data)

app = new Vue
  el: '#app'
  template:'#app'
  vuetify: new Vuetify()

  data: ->
    saved = load()
    headers:
      players: [
        { text: 'Player Name', value: 'name' }
        { text: 'Number of Games Played', value: 'count' }
      ]
      games: [
        {
          text: 'Game'
          value: 'name'
          filter: (v) =>
            if @gameFilter
              console.log 'filter:', v, @gameFilter
              v.toLowerCase().includes(@gameFilter.toLowerCase())
            else
              true
        }
        { text: 'Date', value: 'date' }
        { text: 'Players', value: 'players' }
        { text: 'Location', value: 'location'}
      ]
    plays: saved.plays or bgg.plays.play
    selected: saved.selected or []
    gameFilter: saved.gameFilter or ''

  watch:
    plays: -> save()
    selected: -> save()
    gameFilter: -> save()

  methods:
    filterGames: (v, search, item) ->
      item.name.toLowerCase().includes(v.toLowerCase())

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
          count: commify names[k].length
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
      games.forEach (play) ->
        if Array.isArray(play.players)
          play.players.forEach (player) ->
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
