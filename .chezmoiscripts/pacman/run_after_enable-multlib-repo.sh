#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function is_arch() {
  grep --quiet '^ID=arch$\|^ID_LIKE=arch$' '/etc/os-release'
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

if is_arch && ! grep --quiet '^\[multilib]' '/etc/pacman.conf'; then
  if [[ "$(prompt_yn 'Enable multilib repository?')" == 'y' ]]; then
    log 'Enabling multilib repository'
    sudo sed --null-data 's|#\[multilib]\n#Include|[multilib]\nInclude|' --in-place '/etc/pacman.conf'
    sudo pacman --sync --refresh
    log 'Enabled multilib repository'
  fi
fi
