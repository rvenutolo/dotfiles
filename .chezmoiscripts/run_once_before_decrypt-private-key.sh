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

if ! type -aPf age > /dev/null 2>&1; then
  log 'Downloading age'
  curl --silent --show-error --location --output '/tmp/age.tar.gz' 'https://dl.filippo.io/age/latest?for=linux/amd64'
  tar --extract --gzip --file '/tmp/age.tar.gz' --directory '/tmp' 'age/age'
  chmod +x '/tmp/age/age'
  PATH="/tmp/age:${PATH}"
  log 'Downloaded age'
fi

log 'Decrypting age key'
age --decrypt --output "${age_key_file}" "${CHEZMOI_SOURCE_DIR}/key.txt.age"
log 'Decrypted age key'
chmod 600 "${age_key_file}"
