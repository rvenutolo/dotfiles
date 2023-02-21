#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if ! is_arch; then
  exit 0
fi

if ! executable_exists 'reflector'; then
  exit 0
fi

if ! systemctl is-enabled --user --quiet 'reflector.timer' || ! systemctl is-active --user --quiet 'reflector.timer'; then
  if prompt_yn 'Write: /etc/xdg/reflector/reflector.conf?'; then
    log 'Writing: /etc/xdg/reflector/reflector.conf'
    sudo sed --in-place '/^$/q' '/etc/xdg/reflector/reflector.conf'
    echo -e '--country United States\n--age 12\n--protocol https\n--sort rate\n--save /etc/pacman.d/mirrorlist' |
      sudo tee --append '/etc/xdg/reflector/reflector.conf' > /dev/null
    log 'Wrote: /etc/xdg/reflector/reflector.conf'
  fi
fi

if ! systemctl is-enabled --user --quiet 'reflector.timer' && prompt_yn 'Enable and start reflector services?'; then
  log 'Enabling and starting reflector service'
  sudo systemctl enable --now --quiet 'reflector.timer'
  log 'Enabled and started reflector service'
fi

if ! systemctl is-active --user --quiet 'reflector.timer' && prompt_yn 'Start reflector services?'; then
  log 'Starting reflector service'
  sudo systemctl start --quiet 'reflector.timer'
  log 'Started reflector service'
fi
