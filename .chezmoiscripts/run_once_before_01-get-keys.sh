#!/usr/bin/env bash

set -Eeuo pipefail

function log() {
  echo -e "\033[0;32m[$(date +%T) ${0##*/}] $*\033[0m" >&2
}

function die() {
  echo -e "\033[0;31mDIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]})\033[0m" >&2
  exit 1
}

function executable_exists() {
  command -v "$1" > /dev/null 2>&1
}

function file_exists() {
  [[ -f "$1" ]]
}

function download() {
  curl --disable --fail --silent --location --show-error "$@"
}

if ! executable_exists 'age'; then
  die 'age not found'
fi

if ! executable_exists 'curl'; then
  die 'curl not found'
fi

mkdir --parents "${KEYS_DIR}"

if ! file_exists "${AGE_PRIVATE_KEY_FILE}"; then
  log "Downloading: ${AGE_PRIVATE_KEY_FILE}"
  age_key_content="$(download 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key')"
  if [[ -n "${age_key_content}" ]]; then
    log "Decrypting: ${AGE_PRIVATE_KEY_FILE}"
    until age --decrypt --output "${AGE_PRIVATE_KEY_FILE}" <<< "${age_key_content}"; do :; done
  else
    die "age key file content is empty"
  fi
fi

for filename in 'id_ed25519' 'id_ed25519.pub'; do
  key_file="${KEYS_DIR}/${filename}"
  if ! file_exists "${key_file}"; then
    log "Downloading: ${key_file}"
    key_contents="$(download "https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/${filename}")"
    if [[ -n "${key_contents}" ]]; then
      log "Decrypting: ${key_file}"
      age --decrypt --identity "${AGE_PRIVATE_KEY_FILE}" --output "${key_file}" <<< "${key_contents}"
    else
      die "${filename} content is empty"
    fi
  fi
done

find "${KEYS_DIR}" -type d -exec chmod 700 {} \;
find "${KEYS_DIR}" -type f -exec chmod 600 {} \;
