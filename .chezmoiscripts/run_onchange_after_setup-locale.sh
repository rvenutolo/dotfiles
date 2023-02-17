#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

if ! localectl | grep --quiet --fixed-strings 'LANG=en_US.UTF-8'; then
  log 'Setting locale to en_US.UTF-8'
  if ! grep --quiet '^en_US.UTF-8 UTF-8' '/etc/locale.gen'; then
    echo 'en_US.UTF-8 UTF-8' | sudo tee --append '/etc/locale.gen' > /dev/null
  fi
  sudo locale-gen
  sudo localectl set-locale 'LANG=en_US.UTF-8'
  log 'Set locale to en_US.UTF-8'
fi
