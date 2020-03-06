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
      clearTimeout @timer
      @timer = null
      return unless @user
      @timer = setTimeout =>
        @status = null
        @repos = []
        url = "https://api.github.com/users/#{@user}/repos?per_page=100"
        while url
          try
            res = await axios.get(url)
            @repos.push ...(res.data)
            @status =
              type: 'success'
              text: "Showing #{@repos.length} repos"
            url = res.headers?.link?.match(/<([^>]+)>; rel=.next./)?[1]
          catch err
            @status =
              type: 'error'
              text: err + ' ' + url
            url = null
          finally
            @timer = null
      , 500

  filters:
    humanize: (v) -> moment(v).fromNow()
