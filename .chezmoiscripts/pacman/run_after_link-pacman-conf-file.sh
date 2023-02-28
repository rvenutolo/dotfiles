#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

readonly link_file='/etc/pacman.conf'
readonly target_file="${HOME}/.etc/pacman.conf"

if ! executable_exists 'pacman'; then
  exit 0
fi
if [[ -L "${link_file}" && "$(readlink --canonicalize "${link_file}")" == "$(readlink --canonicalize "${target_file}")" ]]; then
  exit 0
fi
if [[ -f "${link_file}" ]]; then
  diff --color --unified "${link_file}" "${target_file}" || true
  if ! prompt_yn "${link_file} exists - Link: ${target_file} -> ${link_file}?"; then
    exit 0
  fi
else
  if ! prompt_yn "Link: ${target_file} -> ${link_file}?"; then
    exit 0
  fi
fi

log "Linking: ${target_file} -> ${link_file}"
if [[ -f "${link_file}" ]]; then
  sudo rm "${link_file}"
fi
sudo mkdir --parents "$(dirname "${link_file}")"
sudo ln --symbolic "${target_file}" "${link_file}"
log "Linked: ${target_file} -> ${link_file}"

log 'Adding Chaotic AUR keyring and mirror list'
sudo pacman-key --recv-key 'FBA220DFC880C036' --keyserver 'keyserver.ubuntu.com'
sudo pacman-key --lsign-key 'FBA220DFC880C036'
sudo pacman --upgrade --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
log 'Added Chaotic AUR keyring and mirror list'

log 'Refreshing pacman package database'
sudo pacman --sync --refresh
log 'Refreshed pacman package database'
