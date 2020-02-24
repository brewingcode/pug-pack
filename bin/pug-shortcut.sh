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

d="$(readlink "$0")"
if [ -z "$d" ]; then
  d="./$(dirname "$0")"
else
  d="$(dirname "$0")/$(dirname "$d")"
fi
d="$d/.."

case "$1" in
  -l|--list|ls)    shift; ls "$@" "$d/src" ;;
  -f|--find|find)  shift; find "$d/src" "$@" ;;
  -h|--help|help)  usage; exit 0 ;;
  "")              usage; exit 1 ;;
  *) NODE_PATH="$NODE_PATH:$d/node_modules" "$d/node_modules/.bin/pug" -b "$d/src" "$@" ;;
esac
