#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if ! executable_exists 'reflector'; then
  exit 0
fi

## TODO check if this should be a user or system service
if ! systemctl is-enabled --system --quiet 'reflector.timer' && prompt_yn 'Enable and start reflector services?'; then
  log 'Enabling and starting reflector service'
  systemctl enable --now --system --quiet 'reflector.timer'
  log 'Enabled and started reflector service'
fi

if ! systemctl is-active --system --quiet 'reflector.timer' && prompt_yn 'Start reflector services?'; then
  log 'Starting reflector service'
  systemctl start --system --quiet 'reflector.timer'
  log 'Started reflector service'
fi
