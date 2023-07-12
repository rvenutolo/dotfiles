#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $*" >&2
}

function executable_exists() {
  command -v "$1" > /dev/null 2>&1
}

readonly keys_dir="${HOME}/.keys"
readonly age_key_file="${keys_dir}/age.key"

if [[ ! -f "${age_key_file}" ]]; then
  log 'Decrypting age key'
  mkdir --parents "${keys_dir}"
  until age --decrypt --output "${age_key_file}" "${CHEZMOI_SOURCE_DIR}/age.key.ENCRYPTED"; do :; done
  log 'Decrypted age key'
fi

chmod 700 "${keys_dir}"
chmod 600 "${age_key_file}"
