#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

readonly link_file='/etc/fail2ban/jail.local'
readonly target_file="${XDG_CONFIG_HOME}/fail2ban/jail.local"

if [[ -f "${link_file}" ]]; then
  exit 0
fi
if ! prompt_yn "Link: ${target_file} -> ${link_file}?"; then
  exit 0
fi

log "Linking: ${target_file} -> ${link_file}"
sudo mkdir --parents "$(dirname "${link_file}")"
sudo ln --symbolic "${target_file}" "${link_file}"
log "Linked: ${target_file} -> ${link_file}"
