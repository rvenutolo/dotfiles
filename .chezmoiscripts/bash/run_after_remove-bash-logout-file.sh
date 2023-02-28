#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

readonly bash_logout_file="${HOME}/.bash_logout"

if [[ ! -f "${bash_logout_file}" ]]; then
  exit 0
fi
if ! prompt_yn "Delete ${bash_logout_file}?"; then
  exit 0
fi

log "Removing: ${bash_logout_file}"
rm "${bash_logout_file}"
log "Removed: ${bash_logout_file}"
