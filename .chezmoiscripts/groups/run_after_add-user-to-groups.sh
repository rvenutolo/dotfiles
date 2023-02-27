#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

readonly actual_groups="$(groups "${USER}")"
groups=('sys' 'wheel')
if is_personal && is_desktop; then
  groups+=('kvm' 'input' 'libvirt')
fi
readonly groups

for group in "${groups[@]}"; do
  if ! contains_word "${group}" <<< "${actual_groups}" && prompt_yn "Add user to group: ${group}"; then
    log "Adding user to group: ${group}"
    sudo usermod --append --groups "${group}" "${USER}"
    log "Added user to group: ${group}"
  fi
done
