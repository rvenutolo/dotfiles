#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if ! executable_exists 'flatpak'; then
  exit 0
fi
if flatpak remotes --columns=title | contains_word 'Flathub'; then
  exit 0
fi
if ! prompt_yn 'Add Flathub flatpak repo?'; then
  exit 0
fi

log 'Adding Flathub flatpak repo'
flatpak remote-add --if-not-exists 'flathub' 'https://flathub.org/repo/flathub.flatpakrepo'
log 'Added Flathub flatpak repo'
