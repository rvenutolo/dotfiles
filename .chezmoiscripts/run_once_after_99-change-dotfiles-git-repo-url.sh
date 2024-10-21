#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo -e "\033[0;32m[$(date +%T) ${0##*/}] $*\033[0m" >&2
}

function die() {
  echo -e "\033[0;31mDIE: $* (at ${BASH_SOURCE[1]}:${FUNCNAME[1]} line ${BASH_LINENO[0]})\033[0m" >&2
  exit 1
}

source "${HOME}/.profile"
readonly dotfile_git_url='git@github.com:rvenutolo/dotfiles'
log "Setting dotfiles URL to: ${dotfile_git_url}"
git -C "${CODE_DIR}/Personal/dotfiles" remote set-url origin "${dotfile_git_url}"
log "Setting dotfiles URL to: ${dotfile_git_url}"
