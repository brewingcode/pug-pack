#!/bin/bash

# Run CoffeeScript with lots of pre-defined objects/functions:
#
#   s: sugar.js
#   m: moment.js
#   l: lodash.js
#   fs: fs
#   log: console.log()
#   js: JSON.stringify()
#   jp: JSON.parse()
#   fsr: fs.readFileSync()
#   fsw: fs.writeFileSync()
#
# If given args, assumes each arg is a line of the function to run on each
# line of stdin. Without args, just opens the REPL.

d="$(readlink "$0")"
if [ -z "$d" ]; then
  d="./$(dirname "$0")"
else
  d="$(dirname "$0")/$(dirname "$d")"
fi
d="$d/.."

export NODE_PATH="$NODE_PATH:$d/node_modules"

read -r -d '' reqs << EOF
-r s=sugar
-r m=$d/src/moment.js
-r l=$d/src/lodash-custom.js
-r fs
EOF

read -r -d '' shorts << EOF
log = console.log
js = JSON.stringify
jp = JSON.parse
fsr = fs.readFileSync
fsw = fs.writeFileSync
EOF

if [[ "$#" == "0" ]]; then
  echo "copy-paste for shortcuts:"
  echo "$shorts" | paste -sd ';' -
  "$d/node_modules/.bin/coffee" $reqs
else
  t="$(mktemp "/tmp/cs-$$-XXX")"
  cat <<EOF > "$t"
$shorts
g =          # for any globals you want to keep between lines
  h: {}      # a (h)ash
  a: []      # an (a)rray
  end: null  # if defined, call this function after end of input

rl = require('readline').createInterface
  input: process.stdin
  terminal: false
rl.on 'line', (line) ->
EOF

  for i in "$@"; do
    if [[ "$i" =~ ^-(h|-help)$ ]]; then
      echo usage: cs [LINE_OF_CODE ...]
      echo requires:
      echo "$reqs" | perl -pe 's/^/  /gm'
      echo shortcuts:
      echo "$shorts" | perl -pe 's/^/  /gm'
      exit
    fi
    printf "  %s\n" "$i" >> "$t"
  done

  cat <<EOF >> "$t"
rl.on 'close', ->
  g.end() if g.end
EOF

  "$d/node_modules/.bin/coffee" $reqs "$t"
fi
