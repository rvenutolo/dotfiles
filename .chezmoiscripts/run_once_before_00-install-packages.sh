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
