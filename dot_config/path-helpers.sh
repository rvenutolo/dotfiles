#!/usr/bin/env sh

# PATH manipulation helpers. POSIX-compatible so this file can be sourced
# from POSIX sh (profile.sh) or bash (interactive.bash). Function names
# use a `path_` prefix as a namespace; `::` would be cleaner but is not
# POSIX-safe (dash rejects it).
#
# Callers are responsible for unsetting these functions when done if they
# do not want them to remain defined in the shell environment, e.g.
#   unset -f path_remove path_append path_prepend

path_remove() {
  PATH=$(printf '%s' "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"$1"'"' | sed 's/:$//')
}
path_append() {
  path_remove "$1" && PATH="$PATH:$1"
}
path_prepend() {
  path_remove "$1" && PATH="$1:$PATH"
}
