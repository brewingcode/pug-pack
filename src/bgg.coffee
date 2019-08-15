commify = (s) -> s.toString().replace /// \B (?= (\d{3})+ (?!\d) ) ///g, ','

app = new Vue
  el: '#app'
  template:'#app'
  vuetify: new Vuetify()

  data: ->
    headers:
      players: [
        { text: 'Player Name', value: 'name' }
        { text: 'Number of Games Played', value: 'count' }
      ]
      games: [
        { text: 'Game', value: 'name' }
        { text: 'Date', value: 'date' }
        { text: 'Players', value: 'players' }
        { text: 'Location', value: 'location'}
      ]
    plays: bgg.plays.play
    selected: []

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

    commonGames: ->
      return [] if @selected.length < 2
      ids = _.intersection ...@selected.map (player) -> player.plays
      games = []
      @plays.forEach (play) ->
        if play.id in ids
          players = _(play.players)
            .map (p) -> p.name
            .sortBy (p) -> p.toLowerCase()
            .join '<br>'

          games.push
            name: play.item.name
            date: play.date
            players: players
            location: play.location
      return games

    stats: ->
      return unless @commonGames.length > 0

      return
        'Number of games together': @commonGames.length



