#!/usr/bin/env bash

set -euo pipefail

# $1 = URL
# $2 = output file (optional)
function dl() {
  log "Downloading: $1"
  if [[ -n "${2:-}" ]]; then
    tries=0
    until curl --fail --silent --location --show-error "$1" --output "$2"; do
      ((tries += 1))
      if ((${tries} > 10)); then
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  else
    tries=0
    until curl --fail --silent --location --show-error "$1"; do
      ((tries += 1))
      if ((${tries} > 10)); then
        die "Failed to get in 10 tries: ${url}"
      fi
      sleep 15
    done
  fi
}

# $1 = URL
# $2 = output file (optional)
function dl_decrypt() {
  if [[ -n "${2:-}" ]]; then
    dl "$1" | age --decrypt --identity "${HOME}/.keys/age.key" --output "$2"
  else
    dl "$1" | age --decrypt --identity "${HOME}/.keys/age.key"
  fi
}

function log() {
  echo -e "log [$(date +%T)]: $*" >&2
}

function executable_exists() {
  command -v "$1" > /dev/null 2>&1
}

function die() {
  echo -e "DIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]}.)" >&2
  exit 1
}

if ! executable_exists 'age'; then
  die 'age not found'
fi

log 'Getting keys'
if [[ ! -f "${HOME}/.keys/age.key" ]]; then
  mkdir --parents "${HOME}/.keys"
  until dl 'https://raw.githubusercontent.com/rvenutolo/crypt/main/keys/age.key' | age --decrypt --output "${HOME}/.keys/age.key"; do :; done
fi
chmod 700 "${HOME}/.keys"
chmod 600 "${HOME}/.keys/age.key"

dl 'https://api.github.com/repos/rvenutolo/crypt/contents/keys' | grep --fixed-strings 'download_url' | cut --delimiter '"' --fields='4' | while read -r url; do
  filename="$(basename "${url}")"
  if [[ "${filename}" != 'age.key' ]]; then
    dl_decrypt "${url}" "${HOME}/.keys/${filename}"
    chmod 600 "${HOME}/.keys/${filename}"
  fi
done
