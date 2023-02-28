#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if [[ "$(loginctl show-user "${USER}" --property='Linger')" == 'Linger=yes' ]]; then
  exit 0
fi
if ! prompt_yn 'Set user to linger?'; then
  exit 0
fi

log 'Setting user to linger'
sudo loginctl enable-linger "${USER}"
log 'Set user to linger'
