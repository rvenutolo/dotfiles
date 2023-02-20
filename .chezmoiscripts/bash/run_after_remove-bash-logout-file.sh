#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

readonly bash_logout_file="${HOME}/.bash_logout"
if [[ -f "${bash_logout_file}" ]]; then
  if [[ "$(prompt_yn "Delete ${bash_logout_file}?")" == 'y' ]]; then
    log "Removing: ${bash_logout_file}"
    rm "${bash_logout_file}"
    log "Removed: ${bash_logout_file}"
  fi
fi
