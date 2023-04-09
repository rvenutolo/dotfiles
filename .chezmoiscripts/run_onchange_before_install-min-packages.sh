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
  sudo pacman --sync --refresh --needed --noconfirm alacritty bash-completion exa git openssh ttf-jetbrains-mono-nerd
elif executable_exists 'dnf'; then
  sudo dnf copr enable --assumeyes elxreno/jetbrains-mono-fonts
  sudo dnf install --assumeyes alacritty bash-completion exa git jetbrains-mono-fonts openssh
elif executable_exists 'apt'; then
  sudo apt install --assume-yes alacritty bash-completion exa git openssh-client
else
  log 'Unable to determine package manager'
  exit 2
fi
