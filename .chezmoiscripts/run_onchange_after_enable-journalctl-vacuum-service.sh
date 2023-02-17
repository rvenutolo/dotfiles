#!/usr/bin/env bash

set -euo pipefail

function log() {
  echo "${0##*/}: $1" >&2
}

log 'Enabling journalctl-vacuum service'
systemctl --user enable --now 'journalctl-vacuum.timer'
log 'Enabled journalctl-vacuum service'
