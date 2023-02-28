#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if [[ $(timedatectl show) == *'NTP=yes'* ]]; then
  exit 0
fi
if ! prompt_yn 'Set timedatectl NTP on?'; then
  exit 0
fi

log 'Setting timedatectl NTP on'
sudo timedatectl set-ntp on
log 'Set timedatectl NTP on'