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

readonly link_file='/etc/fail2ban/jail.local'
readonly target_file="${XDG_CONFIG_HOME}/fail2ban/jail.local"

if [[ ! -f "${link_file}" ]]; then
  if [[ "$(prompt_yn "Link: ${target_file} -> ${link_file}?")" == 'y' ]]; then
    log "Linking: ${target_file} -> ${link_file}"
    sudo mkdir --parents "$(dirname "${link_file}")"
    sudo ln --symbolic "${target_file}" "${link_file}"
    log "Linked: ${target_file} -> ${link_file}"
  fi
fi
