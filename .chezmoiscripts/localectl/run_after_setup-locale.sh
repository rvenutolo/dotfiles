#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if localectl | grep --quiet --fixed-strings 'LANG=en_US.UTF-8'; then
  exit 0
fi
if ! prompt_yn 'Set locale to en_US.UTF8?'; then
  exit 0
fi

log 'Setting locale to en_US.UTF-8'
if ! grep --quiet '^en_US.UTF-8 UTF-8' '/etc/locale.gen'; then
  echo 'en_US.UTF-8 UTF-8' | sudo tee --append '/etc/locale.gen' > /dev/null
fi
sudo locale-gen
sudo localectl set-locale 'LANG=en_US.UTF-8'
log 'Set locale to en_US.UTF-8'
