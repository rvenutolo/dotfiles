#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function is_arch() {
  grep --quiet '^ID=arch$\|^ID_LIKE=arch$' '/etc/os-release'
}

if is_arch && ! grep --quiet '^\[multilib]' '/etc/pacman.conf'; then
  log 'Enabling multilib repository'
  sudo sed --null-data 's|#\[multilib]\n#Include|[multilib]\nInclude|' --in-place '/etc/pacman.conf'
  sudo pacman --sync --refresh
  log 'Enabled multilib repository'
fi
