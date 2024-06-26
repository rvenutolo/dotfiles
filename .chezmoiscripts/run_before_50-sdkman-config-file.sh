#!/usr/bin/env bash

set -euo pipefail

function die() {
  echo -e "\033[0;31mDIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]})\033[0m" >&2
  exit 1
}

if [[ -z "${SDKMAN_DIR:-}" ]]; then
  exit 0
fi

readonly sdkman_config_file="${SDKMAN_DIR}/etc/config"

if [[ ! -f "${sdkman_config_file}" ]]; then
  exit 0
fi

if [[ -L "${sdkman_config_file}" ]]; then
  exit 0
fi

readonly target_file="${XDG_CONFIG_HOME:-${HOME}/.config}/sdkman/config"

if cmp --silent "${sdkman_config_file}" "${target_file}"; then
  # files have same content, so delete and let chezmoi symlink the file
  log "Removing ${sdkman_config_file}"
  rm "${sdkman_config_file}"
else
  # files have different content
  diff --color "${sdkman_config_file}" "${target_file}"
  die "${sdkman_config_file} and ${target_file} have different contents"
fi
