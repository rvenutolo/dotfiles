#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo -e "$*" >&2
}

function executable_exists() {
  command -v "$1" > /dev/null 2>&1
}

function die() {
  echo -e "DIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}.)" >&2
  exit 1
}

# $1 = url
function dl() {
  curl --fail --silent --location "$1"
}

# $1 = url
function etag_dl() {
  local etag_file="${etags_dir}/$(basename "$1").etag"
  curl --fail --silent --location --etag-compare "${etag_file}" --etag-save "${etag_file}" "$1"
}

if ! prompt_yn 'Install keys?'; then
  exit 0
fi

if ! executable_exists 'age'; then
  die 'age not found'
fi

if ! executable_exists 'curl'; then
  die 'curl not found'
fi

etags_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/etags/keys"
mkdir --parents "${etags_dir}"

keys_dir="${HOME}/.keys"
mkdir --parents "${keys_dir}"

age_key_file="${keys_dir}/age.key"
age_key_contents="$(etag_dl 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key')"
if [[ -n "${age_key_contents}" ]]; then
  log "Decrypting: ${age_key_file}"
  until age --decrypt --output "${age_key_file}" <<< "${age_key_contents}"; do :; done
fi

dl 'https://api.github.com/repos/rvenutolo/crypt/contents/keys' | grep --fixed-strings 'download_url' | cut --delimiter '"' --fields='4' | while read -r url; do
  filename="$(basename "${url}")"
  if [[ "${filename}" != 'age.key' ]]; then
    key_contents="$(etag_dl "${url}")"
    if [[ -n "${key_contents}" ]]; then
      key_file="${keys_dir}/${filename}"
      log "Decrypting: ${key_file}"
      age --decrypt --identity "${age_key_file}" --output "${key_file}" <<< "${key_contents}"
    fi
  fi
done

find "${keys_dir}" -type d -exec chmod 700 {} \;
find "${keys_dir}" -type f -exec chmod 600 {} \;
