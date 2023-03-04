#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $*" >&2
}

function executable_exists() {
  # executables / no builtins, aliases, or functions
  type -aPf "$1" > /dev/null 2>&1
}

if executable_exists 'pacman'; then
  sudo pacman --sync --needed --noconfirm git openssh
elif executable_exists 'dnf'; then
  sudo dnf install --assumeyes git openssh
elif executable_exists 'apt'; then
  sudo apt install --assume-yes git openssh-client
else
  log 'Unable to determine package manager'
  exit 2
fi
