#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if ! executable_exists 'reflector'; then
  exit 0
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
