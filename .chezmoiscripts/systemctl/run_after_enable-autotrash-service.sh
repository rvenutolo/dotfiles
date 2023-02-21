#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if ! executable_exists 'autotrash'; then
  exit 0
fi

if ! systemctl is-enabled --user --quiet 'autotrash.timer' && prompt_yn 'Enable and start autotrash services?'; then
  log 'Enabling and starting autotrash service'
  systemctl enable --now --user --quiet 'autotrash.timer'
  log 'Enabled and started autotrash service'
fi

if ! systemctl is-active --user --quiet 'autotrash.timer' && prompt_yn 'Start autotrash services?'; then
  log 'Starting autotrash service'
  systemctl start --user --quiet 'autotrash.timer'
  log 'Started autotrash service'
fi
