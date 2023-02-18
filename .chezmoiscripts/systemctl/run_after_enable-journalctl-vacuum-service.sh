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

if ! systemctl is-enabled --user --quiet 'journalctl-vacuum.timer'; then
  if [[ "$(prompt_yn 'Enable and start journalctl-vacuum services?')" == 'y' ]]; then
    log 'Enabling and starting journalctl-vacuum service'
    systemctl enable --now --user --quiet 'journalctl-vacuum.timer'
    log 'Enabled and started journalctl-vacuum service'
  fi
elif ! systemctl is-active --user --quiet 'journalctl-vacuum.timer'; then
  if [[ "$(prompt_yn 'Start journalctl-vacuum services?')" == 'y' ]]; then
    log 'Starting journalctl-vacuum service'
    systemctl start --user --quiet 'journalctl-vacuum.timer'
    log 'Started journalctl-vacuum service'
  fi
fi
