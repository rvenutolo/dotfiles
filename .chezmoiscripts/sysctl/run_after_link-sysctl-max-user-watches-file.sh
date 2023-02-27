#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

readonly link_file='/etc/sysctl.d/50-max_user_watches.conf'
readonly target_file="${XDG_CONFIG_HOME}/sysctl/max_user_watches.conf"

if is_headless; then
  exit 0
fi
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
