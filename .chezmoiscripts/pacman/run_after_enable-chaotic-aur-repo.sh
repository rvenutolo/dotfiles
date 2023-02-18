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

if is_arch && ! grep --quiet '^\[chaotic-aur]' '/etc/pacman.conf'; then
  if [[ "$(prompt_yn 'Enable Chaotic AUR?')" == 'y' ]]; then
    log 'Enabling Chaotic AUR'
    sudo pacman-key --recv-key 'FBA220DFC880C036' --keyserver 'keyserver.ubuntu.com'
    sudo pacman-key --lsign-key 'FBA220DFC880C036'
    sudo pacman --upgrade --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
    echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee --append '/etc/pacman.conf' > /dev/null
    sudo pacman --sync --refresh
    log 'Enabled Chaotic AUR'
  fi
fi
