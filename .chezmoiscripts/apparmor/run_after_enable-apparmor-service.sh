#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if ! executable_exists 'aa-enabled'; then
  exit 0
fi

if ! systemctl is-enabled --system --quiet 'apparmor.service' && prompt_yn 'Enable and start apparmor services?'; then
  log 'Enabling and starting apparmor service'
  systemctl enable --now --system --quiet 'apparmor.service'
  log 'Enabled and started apparmor service'
fi

if ! systemctl is-active --system --quiet 'apparmor.service' && prompt_yn 'Start apparmor services?'; then
  log 'Starting apparmor service'
  systemctl start --system --quiet 'apparmor.service'
  log 'Started apparmor service'
fi
