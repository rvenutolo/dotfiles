#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# statusLine command for Claude Code (see settings.json). Resolves the newest
# cached version of the claude-hud plugin and execs its entrypoint.
#
# Symlinked into each profile dir as ${CLAUDE_CONFIG_DIR}/claude-hud.sh, so the
# cache path resolves per-profile rather than to this file's own location.

readonly CACHE_DIR="${CLAUDE_CONFIG_DIR}/plugins/cache/claude-hud/claude-hud"

# Version dirs are semver-named; --version-sort orders 0.10.0 after 0.9.0,
# which a plain lexical sort would not.
LATEST="$(find "${CACHE_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort --version-sort | tail --lines=1)"
readonly LATEST

if [[ -z "${LATEST}" ]]; then
  printf 'claude-hud: no cached plugin version under %s\n' "${CACHE_DIR}" >&2
  exit 1
fi

exec node "${CACHE_DIR}/${LATEST}/dist/index.js"
