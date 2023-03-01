#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if ! executable_exists 'dnf'; then
  exit 0
fi

for repo in 'rpmfusion-free-release' 'rpmfusion-nonfree-release'; do
  if ! dnf list --installed "${repo}" > /dev/null 2>&1 && prompt_yn "Add ${repo} repository?"; then
    sudo dnf install "https://mirrors.rpmfusion.org/free/fedora/${repo}-$(rpm --eval='%fedora').noarch.rpm"
  fi
done
