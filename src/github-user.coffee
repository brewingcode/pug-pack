app = new Vue
  el: '#app'
  template:'#app'
  vuetify: new Vuetify()

  data: ->
    repos: []
    user: ''
    timer: null
    status: null
    headers: [
      { text:'Repo', value:'name' }
      { text:'Last Updated', value:'updated_at' }
      { text:'Watchers', value:'watchers' }
      { text:'Forks', value:'forks' }
      { text:'Original Source', value:'fork' }
    ]

  mounted: ->
    bindInputQueryParam 'input', null, null, (v) => @user = v

  watch:
    user: ->
      return unless @user
      clearTimeout @timer
      @timer = setTimeout =>
        @status = null
        @repos = []
        axios.get("https://api.github.com/users/#{@user}/repos?per_page=100")
          .then (res) =>
            @repos = res.data
            @status =
              type: 'success'
              text: "Showing #{res.data.length} repos"
          .catch (err) =>
            @status =
              type: 'error'
              text: err
          .finally =>
            @timer = null
      , 500

  filters:
    humanize: (v) -> moment(v).fromNow()
