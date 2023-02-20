#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if is_arch && ! grep --quiet '^\[multilib]' '/etc/pacman.conf'; then
  if [[ "$(prompt_yn 'Enable multilib repository?')" == 'y' ]]; then
    log 'Enabling multilib repository'
    sudo sed --null-data 's|#\[multilib]\n#Include|[multilib]\nInclude|' --in-place '/etc/pacman.conf'
    sudo pacman --sync --refresh
    log 'Enabled multilib repository'
  fi
fi
