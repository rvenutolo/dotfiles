#!/usr/bin/env bash

set -euo pipefail

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

function is_readable_file() {
  [[ -f "$1" && -r "$1" ]]
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

readonly keys_dir="${HOME}/.keys"
mkdir --parents "${keys_dir}"

readonly age_key_file="${keys_dir}/age.key"
if ! is_readable_file "${age_key_file}"; then
  log "Downloading: ${age_key_file}"
  age_key_content="$(download 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key')"
  if [[ -n "${age_key_content}" ]]; then
    log "Decrypting: ${age_key_file}"
    until age --decrypt --output "${age_key_file}" <<< "${age_key_content}"; do :; done
  else
    die "age key file content is empty"
  fi
fi

for filename in 'id_ed25519' 'id_ed25519.pub'; do
  key_file="${keys_dir}/${filename}"
  if ! is_readable_file "${key_file}"; then
    log "Downloading: ${key_file}"
    key_contents="$(download "https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/${filename}")"
    if [[ -n "${key_contents}" ]]; then
      log "Decrypting: ${key_file}"
      age --decrypt --identity "${age_key_file}" --output "${key_file}" <<< "${key_contents}"
    else
      die "${filename} content is empty"
    fi
  fi
done

find "${keys_dir}" -type d -exec chmod 700 {} \;
find "${keys_dir}" -type f -exec chmod 600 {} \;
