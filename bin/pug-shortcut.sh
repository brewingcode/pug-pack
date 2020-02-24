#!/bin/bash

# Run pug with -b set to this repo's `src` dir

usage() {
  cat <<'EOF'
A wrapper around running pug with --basedir set to pug-pack's `src` directory.

usage:
  pugs [-l|--list|ls [ARGS]]   # runs `ls` with ARGS in `src`
  pugs [-f|--find|find [ARGS]] # runs `find` with ARGS in `src`
  pugs ARGS                    # runs `pug` with --basedir set to `src` and
                               # ARGS for pug
EOF
}

pproot="$(node -e 'console.log(require.resolve("pug-pack"))')"
pproot="$(dirname "$pproot")/.."

case "$1" in
  -l|--list|ls)    shift; ls "$@" "$pproot/src" ;;
  -f|--find|find)  shift; find "$pproot/src" "$@" ;;
  -h|--help|help)  usage; exit 0 ;;
  "")              usage; exit 1 ;;
  *) NODE_PATH="$NODE_PATH:$pproot/node_modules" "$pproot/node_modules/.bin/pug" -b "$pproot/src" "$@" ;;
esac
