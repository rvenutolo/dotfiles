#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function executable_exists() {
  type -aPf "$1" > /dev/null 2>&1
}

if executable_exists 'reflector'; then
  log 'Enabling reflector service'
  sudo sed --in-place '/^$/q' '/etc/xdg/reflector/reflector.conf'
  echo -e '--country United States\n--age 12\n--protocol https\n--sort rate\n--save /etc/pacman.d/mirrorlist' |
    sudo tee --append '/etc/xdg/reflector/reflector.conf' > /dev/null
  sudo systemctl enable --now 'reflector.timer'
  log 'Enabled reflector service'
fi
