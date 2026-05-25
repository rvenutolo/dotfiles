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

function main() {
  if executable_exists 'apt'; then
    log 'Updating packages with apt'
    sudo apt update
    sudo apt upgrade --yes
    sudo apt install --yes age curl git jq openssh-client
  elif executable_exists 'dnf'; then
    log 'Updating packages with dnf'
    sudo dnf upgrade
    sudo dnf install --assumeyes age curl git jq openssh
  elif executable_exists 'pacman'; then
    log 'Updating packages with pacman'
    sudo pacman --sync --refresh --sysupgrade
    sudo pacman --sync --refresh --needed --noconfirm age curl git jq openssh
  else
    die 'Unknown package manager - Please install age, git, and ssh'
  fi
}

main "$@"
