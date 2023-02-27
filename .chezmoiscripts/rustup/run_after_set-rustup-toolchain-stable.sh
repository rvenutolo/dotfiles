#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if ! executable_exists 'rustup'; then
  exit 0
fi
if [[ "$(rustup toolchain list)" == 'stable'* ]]; then
  exit 0
fi
if ! prompt_yn 'Set rustup toolchain to stable?'; then
  exit 0
fi

log 'Setting rustup toolchain to stable'
rustup toolchain install 'stable'
log 'Set rustup toolchain to stable'
