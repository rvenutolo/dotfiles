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

if executable_exists 'apt'; then
  sudo apt update
  sudo apt upgrade --yes
  sudo apt install --yes age curl git openssh-client
elif executable_exists 'dnf'; then
  sudo dnf upgrade
  sudo dnf install --assumeyes age curl git openssh
elif executable_exists 'pacman'; then
  sudo pacman --sync --refresh --sysupgrade
  sudo pacman --sync --refresh --needed --noconfirm age curl git openssh
else
  log 'Unknown package manager - Please install age, git, and ssh'
  if ! prompt_yn 'Continue?'; then
    log 'Exiting'
    exit 2
  fi
fi
