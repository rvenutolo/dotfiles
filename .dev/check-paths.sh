#!/usr/bin/env bash

# @description Check that every `paths.*` entry in .chezmoidata.yaml exists
# under $HOME (entries are home-relative; some are files, some are dirs, so
# plain existence is tested). Must be run from the repo root.
# @noargs
# @stderr one `missing: <abs-path> (<key>)` line per missing entry
# @exitcode 0 all paths exist
# @exitcode 1 one or more paths are missing

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

readonly DATA_FILE='.chezmoidata.yaml'

function main() {
  local -a entries
  local entry
  local key
  local value
  local missing=0
  mapfile -t entries < <(yq --output-format=tsv '.paths | to_entries | map([.key, .value]) | .[]' "${DATA_FILE}")
  for entry in "${entries[@]}"; do
    key="${entry%%$'\t'*}"
    value="${entry#*$'\t'}"
    if [[ ! -e "${HOME}/${value}" ]]; then
      printf 'missing: %s (%s)\n' "${HOME}/${value}" "${key}" >&2
      missing=1
    fi
  done
  exit "${missing}"
}

main "$@"
