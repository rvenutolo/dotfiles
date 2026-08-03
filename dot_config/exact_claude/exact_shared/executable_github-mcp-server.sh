#!/usr/bin/env bash
# Launch the GitHub MCP server against a specific host, resolving the token from the
# gh CLI keyring at startup so no PAT is ever written to disk. Re-reads the token on
# every launch, so `gh auth login`/`gh auth refresh` is picked up automatically.
#
# Usage: github-mcp-server.sh <hostname> [extra github-mcp-server flags...]
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -lt 1 ]]; then
  printf 'usage: %s <hostname> [github-mcp-server flags...]\n' "${0##*/}" >&2
  exit 64
fi

readonly TARGET_HOST="$1"
shift

for cmd in gh github-mcp-server; do
  if ! command -v "${cmd}" > /dev/null 2>&1; then
    printf '%s: required command not found on PATH: %s\n' "${0##*/}" "${cmd}" >&2
    exit 127
  fi
done

# gh exits non-zero when the host has no stored credential; guard the empty case too
# so a silent success can't start an unauthenticated server.
token="$(gh auth token --hostname "${TARGET_HOST}" 2> /dev/null)" || token=''
if [[ -z "${token}" ]]; then
  printf '%s: no gh token for %s; run: gh auth login --hostname %s\n' \
    "${0##*/}" "${TARGET_HOST}" "${TARGET_HOST}" >&2
  exit 1
fi

export GITHUB_HOST="https://${TARGET_HOST}"
export GITHUB_PERSONAL_ACCESS_TOKEN="${token}"

exec github-mcp-server stdio "$@"
