#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if ! executable_exists 'CrashPlanDesktop'; then
  exit 0
fi

if ! systemctl is-enabled --system --quiet 'crashplan-pro.service' && prompt_yn 'Enable and start crashplan-pro services?'; then
  log 'Enabling and starting crashplan-pro service'
  systemctl enable --now --system --quiet 'crashplan-pro.service'
  log 'Enabled and started crashplan-pro service'
fi

if ! systemctl is-active --system --quiet 'crashplan-pro.service' && prompt_yn 'Start crashplan-pro services?'; then
  log 'Starting crashplan-pro service'
  systemctl start --system --quiet 'crashplan-pro.service'
  log 'Started crashplan-pro service'
fi
