#!/usr/bin/env bash

set -euo pipefail

set +u
readonly current_history_file="${HISTFILE:-"${HOME}/.bash_history"}"
set -u
readonly new_history_file="${XDG_STATE_HOME}/bash/history"

if [[ "${current_history_file}" != "${new_history_file}" ]]; then
  mkdir -p "$(dirname "${new_history_file}")"
  if [[ -f "${current_history_file}" ]]; then
    mv "${current_history_file}" "${new_history_file}"
  else
    touch "${new_history_file}"
  fi
fi
