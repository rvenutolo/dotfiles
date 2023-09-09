#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $*" >&2
}

function executable_exists() {
  command -v "$1" > /dev/null 2>&1
}

function prompt_yn() {
  REPLY=''
  while [[ "${REPLY}" != 'y' && "${REPLY}" != 'n' ]]; do
    read -rp "$1 [Y/n]: "
    if [[ "${REPLY}" == '' || ${REPLY} == [yY] ]]; then
      REPLY='y'
    elif [[ "${REPLY}" == [nN] ]]; then
      REPLY='n'
    fi
  done
  [[ "${REPLY}" == 'y' ]]
}

if executable_exists 'apt-get'; then
  sudo apt-get install --assume-yes age git openssh-client
elif executable_exists 'dnf'; then
  sudo dnf install --assumeyes age git openssh
elif executable_exists 'pacman'; then
  sudo pacman --sync --refresh --needed --noconfirm age git openssh
elif executable_exists 'zypper'; then
  ## TODO fill in
else
  log 'Unknown package manager - Please install age, git, and ssh'
  if ! prompt_yn 'Continue?'; then
    log 'Exiting'
    exit 2
  fi
fi
