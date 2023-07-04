#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $*" >&2
}

if [[ -z "${SDKMAN_DIR-}" ]]; then
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
  rm "${sdkman_config_file}"
else
  # files have different content
  log "${sdkman_config_file} and ${target_file} have different contents"
  diff --color "${sdkman_config_file}" "${target_file}"
  exit 2
fi
