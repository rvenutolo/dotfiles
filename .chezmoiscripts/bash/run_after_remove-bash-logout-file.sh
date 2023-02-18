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

readonly bash_logout_file="${HOME}/.bash_logout"
if [[ -f "${bash_logout_file}" ]]; then
  if [[ "$(prompt_yn "Delete ${bash_logout_file}?")" == 'y' ]]; then
    log "Removing: ${bash_logout_file}"
    rm "${bash_logout_file}"
    log "Removed: ${bash_logout_file}"
  fi
fi
