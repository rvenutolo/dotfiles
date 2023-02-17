#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function is_arch() {
  grep --quiet '^ID=arch$\|^ID_LIKE=arch$' '/etc/os-release'
}

if is_arch && ! grep --quiet '^\[chaotic-aur]' '/etc/pacman.conf'; then
  log 'Enabling Chaotic AUR'
  sudo pacman-key --recv-key 'FBA220DFC880C036' --keyserver 'keyserver.ubuntu.com'
  sudo pacman-key --lsign-key 'FBA220DFC880C036'
  sudo pacman --upgrade --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
  echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee --append '/etc/pacman.conf' > /dev/null
  sudo pacman --sync --refresh
  log 'Enabled Chaotic AUR'
fi
