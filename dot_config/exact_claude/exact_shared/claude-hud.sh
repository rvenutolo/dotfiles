#!/usr/bin/env bash

set -euo pipefail

CACHE_DIR="${CLAUDE_CONFIG_DIR}/plugins/cache/claude-hud/claude-hud"
LATEST=$(ls -v "${CACHE_DIR}" | tail --lines=1)
exec node "${CACHE_DIR}/${LATEST}/dist/index.js"
