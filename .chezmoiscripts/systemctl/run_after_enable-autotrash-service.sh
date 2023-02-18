#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function executable_exists() {
  type -aPf "$1" > /dev/null 2>&1
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

if executable_exists 'autotrash'; then
  if ! systemctl is-enabled --user --quiet 'autotrash.timer'; then
    if [[ "$(prompt_yn 'Enable and start autotrash services?')" == 'y' ]]; then
      log 'Enabling and starting autotrash service'
      systemctl enable --now --user --quiet 'autotrash.timer'
      log 'Enabled and started autotrash service'
    fi
  elif ! systemctl is-active --user --quiet 'autotrash.timer'; then
    if [[ "$(prompt_yn 'Start autotrash services?')" == 'y' ]]; then
      log 'Starting autotrash service'
      systemctl start --user --quiet 'autotrash.timer'
      log 'Started autotrash service'
    fi
  fi
fi
