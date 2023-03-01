#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

readonly service='autotrash.timer'
readonly desc='Autotrash'
readonly system_or_user='user'
readonly executable='autotrash'

if ! executable_exists "${executable}"; then
  exit 0
fi

if ! systemctl is-enabled --"${system_or_user}" --quiet "${service}" && prompt_yn "Enable and start ${desc} service?"; then
  log "Enabling and starting ${desc} service"
  systemctl enable --now --"${system_or_user}" --quiet "${service}"
  log "Enabled and started ${desc} service"
fi

if ! systemctl is-active --"${system_or_user}" --quiet "${service}" && prompt_yn "Start ${desc} service?"; then
  log "Starting ${desc} service"
  systemctl start --"${system_or_user}" --quiet "${service}"
  log "Started ${desc} service"
fi
