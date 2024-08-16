#!/usr/bin/env bash

# https://unix.stackexchange.com/questions/9123/is-there-a-one-liner-that-allows-me-to-create-a-directory-and-move-into-it-at-th/9124#9124
function mkcd() {
  [[ "$#" -ne 1 ]] && echo "${0##*/}: Expected exactly 1 argument" >&2 && return 2
  case "$1" in
    */.. | */../) cd -- "$1" || return 2 ;; # that doesn't make any sense unless the directory already exists
    /*/../*) (cd "${1%/../*}/.." && mkdir --parents "./${1##*/../}") && cd -- "$1" || return 2 ;;
    /*) mkdir --parents "$1" && cd "$1" || return 2 ;;
    */../*) (cd "./${1%/../*}/.." && mkdir --parents "./${1##*/../}") && cd "./$1" || return 2 ;;
    ../*) (cd .. && mkdir --parents "${1#.}") && cd "$1" || return 2 ;;
    *) mkdir --parents "./$1" && cd "./$1" || return 2 ;;
  esac
}

function cl() {
  cd "$@" && eval ll
}

function fff() {
  command fff "$@"
  cd "$(cat "${XDG_CACHE_HOME:=${HOME}/.cache}/fff/.fff_d")" || return 2
}

function functions() {
  typeset -F | cut --delimiter=' ' --fields=3 | while read -r func; do
    (
      shopt -s extdebug
      declare -F "${func}"
    ) | awk '{ print $1, $3":"$2 }'
  done |
    sed "s#${HOME}#~#g" |
    column --table --table-columns 'FUNCTION,SOURCE' --table-truncate 1
}

function aliases() {
  PS4='+$BASH_SOURCE ' BASH_XTRACEFD=7 bash -xic ':' 7> >(
    grep --perl-regexp '^\++\S+ alias ' |
      sed 's/^\+*//' |
      sed --regexp-extended "s#([^\])'#\1#g" |
      awk -F' alias ' -v OFS='‽' '{ print $2, $1 }' |
      LC_COLLATE=C sort
  ) |
    sed "s#${HOME}#~#g" |
    column --separator '‽' --table --table-columns 'ALIAS,SOURCE' --table-columns-limit 2 --table-truncate 1
}

function history-commands() {
  HISTTIMEFORMAT="" history |
    awk '{CMD[$2]++;count++;}END { for (a in CMD)print CMD[a] " " CMD[a]/count*100 "% " a;}' |
    grep -v "./" |
    column -c3 -s " " -t |
    sort -nr |
    nl
}

function ipv4_to_num() {
  IFS=. read -r a b c d <<< "$*"
  printf '%d\n' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

function tmpd() {
  cd "$(mktemp --directory)" || exit
}
