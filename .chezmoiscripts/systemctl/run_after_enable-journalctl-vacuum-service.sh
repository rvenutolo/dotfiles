#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if ! systemctl is-enabled --user --quiet 'journalctl-vacuum.timer' && prompt_yn 'Enable and start journalctl-vacuum services?'; then
  log 'Enabling and starting journalctl-vacuum service'
  systemctl enable --now --user --quiet 'journalctl-vacuum.timer'
  log 'Enabled and started journalctl-vacuum service'
fi

if ! systemctl is-active --user --quiet 'journalctl-vacuum.timer' && prompt_yn 'Start journalctl-vacuum services?'; then
  log 'Starting journalctl-vacuum service'
  systemctl start --user --quiet 'journalctl-vacuum.timer'
  log 'Started journalctl-vacuum service'
fi
