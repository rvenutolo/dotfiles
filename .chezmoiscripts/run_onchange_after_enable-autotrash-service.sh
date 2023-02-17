#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

function executable_exists() {
  type -aPf "$1" > /dev/null 2>&1
}

if executable_exists 'autotrash'; then
  log 'Enabling autotrash service'
  systemctl --user enable --now 'autotrash.timer'
  log 'Enabled autotrash service'
else
  log 'Not enabling autotrash service -- autotrash executable does not exist'
fi
