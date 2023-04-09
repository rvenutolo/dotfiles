#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $*" >&2
}

age_key_file="$(dirname "${CHEZMOI_CONFIG_FILE}")/age_key.txt"
readonly age_key_file

if [[ -f "${age_key_file}" ]]; then
  exit 0
fi

log 'Decrypting age key'
until age --decrypt --output "${age_key_file}" "${CHEZMOI_SOURCE_DIR}/key.txt.age"; do :; done
log 'Decrypted age key'
chmod 600 "${age_key_file}"
