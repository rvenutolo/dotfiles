#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function executable_exists() {
  type -aPf "$1" > /dev/null 2>&1
}

function prompt_yn() {
  local prompt_reply=''
  while [[ "${prompt_reply}" != 'y' && "${prompt_reply}" != 'n' ]]; do
    read -rp "$1 [Y/n]" prompt_reply
    if [[ "${prompt_reply}" == '' || ${prompt_reply} == [yY] ]]; then
      prompt_reply='y'
    elif [[ "${prompt_reply}" == [nN] ]]; then
      prompt_reply='n'
    fi
  done
  echo "${prompt_reply}"
}

if executable_exists 'git'; then
  readonly chezmoi_dotfiles_dir="${CODE_DIR}/chezmoi-dotfiles"
  readonly origin_url="$(git --git-dir "${chezmoi_dotfiles_dir}/.git" remote get-url origin)"
  if [[ "${origin_url}" == 'http*' ]]; then
    git --git-dir "${chezmoi_dotfiles_dir}/.git" remote set-url 'origin' 'git@github.com:rvenutolo/chezmoi-dotfiles.git'
  fi
fi
