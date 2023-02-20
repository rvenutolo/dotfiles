#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if ! systemctl is-enabled --user --quiet 'journalctl-vacuum.timer'; then
  if [[ "$(prompt_yn 'Enable and start journalctl-vacuum services?')" == 'y' ]]; then
    log 'Enabling and starting journalctl-vacuum service'
    systemctl enable --now --user --quiet 'journalctl-vacuum.timer'
    log 'Enabled and started journalctl-vacuum service'
  fi
elif ! systemctl is-active --user --quiet 'journalctl-vacuum.timer'; then
  if [[ "$(prompt_yn 'Start journalctl-vacuum services?')" == 'y' ]]; then
    log 'Starting journalctl-vacuum service'
    systemctl start --user --quiet 'journalctl-vacuum.timer'
    log 'Started journalctl-vacuum service'
  fi
fi
