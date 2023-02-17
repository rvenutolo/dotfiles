#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

readonly link_file='/etc/fail2ban/jail.local'
readonly target_file="${XDG_CONFIG_HOME}/fail2ban/jail.local"

if [[ ! -f "${link_file}" ]]; then
  log "Linking ${target_file} -> ${link_file}"
  sudo mkdir --parents "$(dirname "${link_file}")"
  sudo ln --symbolic "${target_file}" "${link_file}"
  log "Linked ${target_file} -> ${link_file}"
fi
