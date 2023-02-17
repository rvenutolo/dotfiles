#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

readonly bash_logout_file="${HOME}/.bash_logout"
if [[ -f "${bash_logout_file}" ]]; then
  log "Removing ${bash_logout_file}"
  rm "${bash_logout_file}"
  log "Removed ${bash_logout_file}"
fi
