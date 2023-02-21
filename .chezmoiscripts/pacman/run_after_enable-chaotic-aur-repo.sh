#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if ! is_arch; then
  exit 0
fi
if grep --quiet '^\[chaotic-aur]' '/etc/pacman.conf'; then
  exit 0
fi
if ! prompt_yn 'Enable Chaotic AUR?'; then
  exit 0
fi

log 'Enabling Chaotic AUR'
sudo pacman-key --recv-key 'FBA220DFC880C036' --keyserver 'keyserver.ubuntu.com'
sudo pacman-key --lsign-key 'FBA220DFC880C036'
sudo pacman --upgrade --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee --append '/etc/pacman.conf' > /dev/null
sudo pacman --sync --refresh
log 'Enabled Chaotic AUR'
