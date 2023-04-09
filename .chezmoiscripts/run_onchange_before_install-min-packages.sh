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
  sudo pacman --sync --refresh --needed --noconfirm bash-completion git openssh
elif executable_exists 'dnf'; then
  sudo dnf install --assumeyes bash-completion git openssh
elif executable_exists 'apt'; then
  sudo apt install --assume-yes bash-completion git openssh-client
else
  log 'Unable to determine package manager'
  exit 2
fi
