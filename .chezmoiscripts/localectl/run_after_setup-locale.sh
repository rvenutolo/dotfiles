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

if ! localectl | grep --quiet --fixed-strings 'LANG=en_US.UTF-8'; then
  if [[ "$(prompt_yn 'Set locale to en_US.UTF8?')" == 'y' ]]; then
    log 'Setting locale to en_US.UTF-8'
    if ! grep --quiet '^en_US.UTF-8 UTF-8' '/etc/locale.gen'; then
      echo 'en_US.UTF-8 UTF-8' | sudo tee --append '/etc/locale.gen' > /dev/null
    fi
    sudo locale-gen
    sudo localectl set-locale 'LANG=en_US.UTF-8'
    log 'Set locale to en_US.UTF-8'
  fi
fi
