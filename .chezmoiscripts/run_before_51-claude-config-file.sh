#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo -e "\033[0;32m[$(date +%T) ${0##*/}] $*\033[0m" >&2
}

function die() {
  echo -e "\033[0;31mDIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]})\033[0m" >&2
  exit 1
}

readonly claude_config_file="${XDG_CONFIG_HOME}/claude/shared/settings.json"

if [[ ! -f "${claude_config_file}" ]]; then
  exit 0
fi

readonly temp_file="$(mktemp)"

jq --sort-keys '.' "${claude_config_file}" > "${temp_file}"
mv "${temp_file}" "${claude_config_file}"
