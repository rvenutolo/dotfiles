#!/usr/bin/env bash

set -euo pipefail

set +u
readonly current_history_file="${LESSHISTFILE:-"${HOME}/.lesshst"}"
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

readonly new_history_file="${LESSHISTFILE}"
mkdir --parents "$(dirname "${new_history_file}")"

if [[ ! -f "${current_history_file}" ]]; then
  exit 0
fi
if [[ "${current_history_file}" == "${new_history_file}" ]]; then
  exit 0
fi
if ! prompt_yn "Move ${current_history_file} -> ${new_history_file}?"; then
  exit 0
fi

log "Moving: ${current_history_file} -> ${new_history_file}"
mv "${current_history_file}" "${new_history_file}"
log "Moved: ${current_history_file} -> ${new_history_file}"
