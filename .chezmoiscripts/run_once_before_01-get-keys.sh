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

# $1 = file
function is_readable_file() {
  [[ -f "$1" && -r "$1" ]]
}

function auto_answer() {
  [[ "${SCRIPTS_AUTO_ANSWER:-}" == [Yy] ]]
}

# $1 = question
function prompt_ny() {
  REPLY=''
  if auto_answer; then
    REPLY='n'
  fi
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [y/N]: "
    if [[ "${REPLY}" == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == '' || "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

# $1 = url
function dl() {
  curl --disable --fail --silent --location --show-error "$@"
}

if ! executable_exists 'age'; then
  die 'age not found'
fi

if ! executable_exists 'curl'; then
  die 'curl not found'
fi

keys_dir="${HOME}/.keys"
mkdir --parents "${keys_dir}"

readonly age_key_file="${keys_dir}/age.key"

if ! is_readable_file "${age_key_file}" || prompt_ny "${age_key_file} exists - Download again?"; then
  log "Downloading: ${age_key_file}"
  age_key_content="$(download 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key')"
  if [[ -n "${age_key_content}" ]]; then
    log "Decrypting: ${age_key_file}"
    until age --decrypt --output "${age_key_file}" <<< "${age_key_content}"; do :; done
  else
    die "age key file content is empty"
  fi
fi

function dl_key() {
  log "Downloading: ${key_file}"
  key_contents="$(download "${url}")"
  if [[ -n "${key_contents}" ]]; then
    log "Decrypting: ${key_file}"
    age --decrypt --identity "${age_key_file}" --output "${key_file}" <<< "${key_contents}"
  else
    die "${filename} content is empty"
  fi
}

for url in $(download 'https://api.github.com/repos/rvenutolo/crypt/contents/keys' | jq -r '.[].download_url'); do
  filename="$(basename "${url}")"
  if [[ "${filename}" == 'age.key' ]]; then
    continue
  fi
  key_file="${keys_dir}/${filename}"
  if is_readable_file "${key_file}"; then
    if prompt_ny "${key_file} already exists - Download again?"; then
      dl_key
    fi
  else
    if [[ "${filename}" == 'id_ed25519' ]]; then
      dl_key
    elif prompt_ny "Download ${key_file}"; then
      dl_key
    fi
  fi
done

find "${keys_dir}" -type d -exec chmod 700 {} \;
find "${keys_dir}" -type f -exec chmod 600 {} \;
