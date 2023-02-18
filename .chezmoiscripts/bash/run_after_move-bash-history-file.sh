#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function prompt_yn() {
  local prompt_reply=''
  while [[ "${prompt_reply}" != 'y' && "${prompt_reply}" != 'n' ]]; do
    read -rp "$1 [Y/n]" prompt_reply
    if [[ "${prompt_reply}" == '' || ${prompt_reply} == [yY] ]]; then
      prompt_reply='y'
    elif [[ "${prompt_reply}" == [nN] ]]; then
      prompt_reply='n'
    fi
  done
  echo "${prompt_reply}"
}

set +u
readonly current_history_file="${HISTFILE:-"${HOME}/.bash_history"}"
set -u

readonly bash_exports_file="${XDG_CONFIG_HOME}/bash/exports"
if [[ -f "${bash_exports_file}" ]]; then
  set +u
  source "${bash_exports_file}"
  set -u
fi
readonly new_history_file="${HISTFILE}"

if [[ -f "${current_history_file}" && "${current_history_file}" != "${new_history_file}" ]]; then
  if [[ "$(prompt_yn "Move ${current_history_file} -> ${new_history_file}?")" == 'y' ]]; then
    log "Moving: ${current_history_file} -> ${new_history_file}"
    mv "${current_history_file}" "${new_history_file}"
    log "Moved: ${current_history_file} -> ${new_history_file}"
  fi
fi
