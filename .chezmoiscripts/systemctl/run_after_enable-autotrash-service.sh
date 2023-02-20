#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if executable_exists 'autotrash'; then
  if ! systemctl is-enabled --user --quiet 'autotrash.timer'; then
    if [[ "$(prompt_yn 'Enable and start autotrash services?')" == 'y' ]]; then
      log 'Enabling and starting autotrash service'
      systemctl enable --now --user --quiet 'autotrash.timer'
      log 'Enabled and started autotrash service'
    fi
  elif ! systemctl is-active --user --quiet 'autotrash.timer'; then
    if [[ "$(prompt_yn 'Start autotrash services?')" == 'y' ]]; then
      log 'Starting autotrash service'
      systemctl start --user --quiet 'autotrash.timer'
      log 'Started autotrash service'
    fi
  fi
else
  log 'autotrash not found - Skipping enabling and starting autotrash service'
fi
