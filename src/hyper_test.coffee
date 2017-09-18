{ h, app } = hyperapp

app
  root: document.getElementById 'app'
  state:
    count: 0
  view: (state, actions) ->
    h 'div', null, [
      h 'h1', null, state.count
      h 'button',
        onclick: actions.sub
        disabled: state.count <= 0
      , 'ー'
      h 'button',
        onclick: actions.add
      , '＋'
    ]
  actions:
    sub: (state) -> count: state.count - 1
    add: (state) -> count: state.count + 1
