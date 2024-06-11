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
  curl --fail --silent --location "$1"
}

if ! executable_exists 'age'; then
  die 'age not found'
fi

if ! executable_exists 'curl'; then
  die 'curl not found'
fi

keys_dir="${HOME}/.keys"
mkdir --parents "${keys_dir}"

age_key_file="${keys_dir}/age.key"
age_key_contents="$(dl 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key')"
if [[ -n "${age_key_content}" ]]; then
  log "Decrypting: ${age_key_file}"
  until age --decrypt --output "${age_key_file}" <<< "${age_key_contents}"; do :; done
fi

for url in $(dl 'https://api.github.com/repos/rvenutolo/crypt/contents/keys' | jq -r '.[].download_url'); do
  filename="$(basename "${url}")"
  if [[ "${filename}" == 'age.key' ]]; then
    continue
  fi
  key_contents="$(dl "${url}")"
  if [[ -n "${key_contents}" ]]; then
    if [[ "${filename}" == "id_ed25519" ]] || prompt_ny "Decrypt ${filename}?"; then
      key_file="${keys_dir}/${filename}"
      log "Decrypting: ${key_file}"
      age --decrypt --identity "${age_key_file}" --output "${key_file}" <<< "${key_contents}"
    fi
  fi
done

find "${keys_dir}" -type d -exec chmod 700 {} \;
find "${keys_dir}" -type f -exec chmod 600 {} \;
