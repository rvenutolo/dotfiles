#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo -e "\033[0;32m[$(date +%T) ${0##*/}] $*\033[0m" >&2
}

source "${HOME}/.profile"
readonly dotfile_git_url='git@github.com:rvenutolo/dotfiles'
log "Setting dotfiles URL to: ${dotfile_git_url}"
git -C "${CODE_DIR}/Personal/dotfiles" remote set-url origin "${dotfile_git_url}"
log "Set dotfiles URL to: ${dotfile_git_url}"
