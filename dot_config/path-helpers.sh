#!/usr/bin/env sh

# PATH manipulation helpers. POSIX-compatible so this file can be sourced
# from POSIX sh (profile.sh) or bash (interactive.bash). Function names
# use a `path_` prefix as a namespace; `::` would be cleaner but is not
# POSIX-safe (dash rejects it).
#
# Usage:
#   . "${XDG_CONFIG_HOME}/path-helpers.sh"
#   path_append "/some/dir"
#   path_prepend "/another/dir"
#   path_dedup XDG_DATA_DIRS  # any colon-separated variable, by name
#   path_helpers_unset    # removes the helpers from the shell environment

path_remove() {
  PATH=$(printf '%s' "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"$1"'"' | sed 's/:$//')
}
path_append() {
  path_remove "$1" && PATH="$PATH:$1"
}
path_prepend() {
  path_remove "$1" && PATH="$1:$PATH"
}
# Keeps the first occurrence of each entry, so earlier entries keep their
# precedence, and drops empty entries.
path_dedup() {
  case "$1" in
    '' | [!A-Za-z_]* | *[!A-Za-z0-9_]*) return 1 ;;
  esac
  eval "__path_dedup_val=\${$1:-}"
  __path_dedup_val=$(printf '%s' "$__path_dedup_val" | awk -v RS=: -v ORS=: 'NF && !seen[$0]++' | sed 's/:$//')
  eval "$1=\$__path_dedup_val"
  unset -v __path_dedup_val
}
path_helpers_unset() {
  unset -f path_remove path_append path_prepend path_dedup path_helpers_unset
}
