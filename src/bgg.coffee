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
    stats: {}

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
        .filter (p) ->
          p.count > 10
        .sortBy (p) ->
          +p.count
        .reverse()
        .value()

    commonGames: -> []
