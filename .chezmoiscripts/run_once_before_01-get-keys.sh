#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
trap 'printf "error: line %s (exit %d): %s\n" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR

function log() {
  printf '\033[0;32m[%s %s] %s\033[0m\n' "$(date +%T)" "${0##*/}" "$*" >&2
}

function die() {
  printf '\033[0;31mDIE: %s (at %s:%s line %s)\033[0m\n' \
    "$*" "${BASH_SOURCE[1]}" "${FUNCNAME[1]}" "${BASH_LINENO[0]}" >&2
  exit 1
}

function executable_exists() {
  local -r cmd="$1"
  command -v "${cmd}" > /dev/null 2>&1
}

function file_exists() {
  local -r path="$1"
  [[ -f "${path}" ]]
}

function download() {
  curl --disable --fail --silent --location --show-error "$@"
}

function main() {
  if ! executable_exists 'age'; then
    die 'age not found'
  fi

  if ! executable_exists 'curl'; then
    die 'curl not found'
  fi

  mkdir --parents "${KEYS_DIR}"

  if ! file_exists "${AGE_PRIVATE_KEY_FILE}"; then
    log "Downloading: ${AGE_PRIVATE_KEY_FILE}"
    local age_key_content
    age_key_content="$(download 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key')"
    if [[ -n "${age_key_content}" ]]; then
      log "Decrypting: ${AGE_PRIVATE_KEY_FILE}"
      until age --decrypt --output "${AGE_PRIVATE_KEY_FILE}" <<< "${age_key_content}"; do :; done
    else
      die 'age key file content is empty'
    fi
  fi

  local filename key_file key_contents
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
}

main "$@"
