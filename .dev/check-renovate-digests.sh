#!/usr/bin/env bash

# @description Verify every "# renovate:" tagged entry in
# .chezmoiexternal.toml.tmpl is followed by a `url = ` line containing a
# pinned 40-hex-char SHA before the next "# renovate:" comment or EOF.
# Must be run from the repo root.
#
# Renovate's custom regex manager compiles matchStrings with RE2, which has
# no negative lookahead, so the bridge between the "# renovate:" comment and
# its `url = ` line cannot be anchored to stop at the next comment. Without
# that anchor, a renovate-tagged entry whose own block has no digest lets the
# bridge cross into the *next* block and silently bind that entry's SHA to
# the wrong package (see .github/renovate.json5 and #94). This script is the
# enforcement fallback: it fails the commit before that mismatch can land.
# @noargs
# @stderr one `no digest in url after: <comment>` line per violation
# @exitcode 0 every renovate-tagged entry has a pinned digest
# @exitcode 1 one or more renovate-tagged entries lack a digest

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

readonly EXTERNALS_FILE='.chezmoiexternal.toml.tmpl'

# @description Print an error message to stderr and exit non-zero.
# @arg $@ message to print
function die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

function main() {
  local -i failures=0
  local block_comment=''
  local block_has_digest='false'
  local line
  while IFS= read -r line; do
    if [[ "${line}" == '# renovate:'* ]]; then
      if [[ -n "${block_comment}" && "${block_has_digest}" == 'false' ]]; then
        printf 'no digest in url after: %s\n' "${block_comment}" >&2
        failures+=1
      fi
      block_comment="${line}"
      block_has_digest='false'
    elif [[ -n "${block_comment}" && "${line}" =~ url\ =\ .*[0-9a-f]{40} ]]; then
      block_has_digest='true'
    fi
  done < "${EXTERNALS_FILE}"
  if [[ -n "${block_comment}" && "${block_has_digest}" == 'false' ]]; then
    printf 'no digest in url after: %s\n' "${block_comment}" >&2
    failures+=1
  fi
  ((failures == 0)) || die "${failures} renovate-tagged entries lack a pinned digest"
}

main "$@"
