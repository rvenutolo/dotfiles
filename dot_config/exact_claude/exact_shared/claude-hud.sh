#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

# statusLine command for Claude Code (see settings.json). Resolves the
# installed version of the claude-hud plugin and execs its entrypoint.
#
# Symlinked into each profile dir as ${CLAUDE_CONFIG_DIR}/claude-hud.sh, so the
# plugin registry resolves per-profile rather than to this file's own location.

readonly PLUGINS_FILE="${CLAUDE_CONFIG_DIR}/plugins/installed_plugins.json"
readonly PLUGIN_ID='jarrodwatts--hud@rvenutolo-pins'

# The registry's installPath, not the newest dir under the plugin's cache: an
# install from a SHA-pinned marketplace can leave a commit-named dir beside the
# semver one, and a version sort ranks that stray above the real install.
INSTALL_PATH="$(jq --raw-output --arg id "${PLUGIN_ID}" '.plugins[$id][0].installPath // empty' "${PLUGINS_FILE}")"
readonly INSTALL_PATH

if [[ -z "${INSTALL_PATH}" ]]; then
  printf 'claude-hud: %s is not installed per %s\n' "${PLUGIN_ID}" "${PLUGINS_FILE}" >&2
  exit 1
fi

exec node "${INSTALL_PATH}/dist/index.js"
