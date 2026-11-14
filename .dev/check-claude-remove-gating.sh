#!/usr/bin/env bash

# @description Assert that the rendered `.chezmoiremove` lists the Claude
# server-removal entries only where they belong. On a personal or work host
# those entries would delete the live `~/.config/claude` (owned by the second
# chezmoi instance) without a prompt, and a dry-run render cannot see that, so
# the per-host CI render job runs this against the host class it has become.
# The result depends on the host class, which is why this is not a pre-commit
# hook.
#
# Renders with chezmoi's current config unless CHECK_GATING_CHEZMOI_CONFIG
# names another config file, which lets a scratch config simulate a host class
# locally. The source is always the repo this script lives in.
# @arg $1 `absent` (personal and work hosts) or `present` (server hosts)
# @stderr one line per violation, or the reason the render could not run
# @exitcode 0 the rendered list matches the expectation
# @exitcode 1 the rendered list violates the expectation
# @exitcode 2 usage error, or `.chezmoiremove` could not be rendered

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

readonly -a GUARDED_SCRIPTS=(
  '.local/bin/claude-worktree-guard'
  '.local/bin/ssh-signing-key-reminder'
)
readonly -a REQUIRED_ON_SERVER=(
  '.config/claude/shared'
  "${GUARDED_SCRIPTS[@]}"
)

tmp_dir=''

# @description Print usage to stderr.
# @noargs
# @stderr the usage line
function usage() {
  printf 'usage: %s <present|absent>\n' "${0##*/}" >&2
}

# @description Render `.chezmoiremove` into one trimmed entry per line,
# dropping blank lines and `#` comments as chezmoi does.
# @arg $1 out file to write the entries to
# @exitcode 0 rendered
# @exitcode 2 chezmoi failed to render the file
function render_entries() {
  local -r out="$1"
  local repo_root
  repo_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
  local -a chezmoi_args=(execute-template --no-tty --source "${repo_root}")
  if [[ -n "${CHECK_GATING_CHEZMOI_CONFIG:-}" ]]; then
    chezmoi_args+=(--config "${CHECK_GATING_CHEZMOI_CONFIG}")
  fi
  if ! chezmoi "${chezmoi_args[@]}" < "${repo_root}/.chezmoiremove" > "${tmp_dir}/rendered"; then
    printf 'FAIL: could not render .chezmoiremove\n' >&2
    exit 2
  fi
  sed --expression='s/^[[:space:]]*//' --expression='s/[[:space:]]*$//' "${tmp_dir}/rendered" \
    | { grep --invert-match --extended-regexp '^(#|$)' || true; } > "${out}" # no entries at all is valid
}

# @description Fail on any entry that removes Claude config or the guarded scripts.
# @arg $1 entries file
# @stderr one FAIL line per offending entry
# @exitcode 0 no offending entry
# @exitcode 1 at least one offending entry
function check_absent() {
  local -r entries_file="$1"
  local -a entries
  local entry
  local script
  local status=0
  mapfile -t entries < "${entries_file}"
  for entry in "${entries[@]}"; do
    if [[ "${entry}" =~ ^\.config/claude ]]; then
      printf 'FAIL: .chezmoiremove removes Claude config on this host: %s\n' "${entry}" >&2
      status=1
    fi
    for script in "${GUARDED_SCRIPTS[@]}"; do
      if [[ "${entry}" == "${script}" ]]; then
        printf 'FAIL: .chezmoiremove removes a Claude hook script on this host: %s\n' "${entry}" >&2
        status=1
      fi
    done
  done
  return "${status}"
}

# @description Fail unless every server-removal entry is present.
# @arg $1 entries file
# @stderr one FAIL line per missing entry
# @exitcode 0 every required entry is present
# @exitcode 1 at least one required entry is missing
function check_present() {
  local -r entries_file="$1"
  local required
  local status=0
  for required in "${REQUIRED_ON_SERVER[@]}"; do
    if ! grep --quiet --line-regexp --fixed-strings -- "${required}" "${entries_file}"; then
      printf 'FAIL: .chezmoiremove is missing a server removal entry: %s\n' "${required}" >&2
      status=1
    fi
  done
  return "${status}"
}

# @description Render `.chezmoiremove` and check it against the expectation.
# @arg $1 expectation, `present` or `absent`
# @exitcode 0 the expectation holds
# @exitcode 1 the expectation does not hold
function main() {
  local -r expectation="$1"
  local status=0
  render_entries "${tmp_dir}/entries"
  case "${expectation}" in
    absent)
      check_absent "${tmp_dir}/entries" || status=1
      ;;
    present)
      check_present "${tmp_dir}/entries" || status=1
      ;;
  esac
  if ((status == 0)); then
    printf 'OK: Claude removal entries are %s as expected\n' "${expectation}" >&2
  fi
  exit "${status}"
}

if (($# != 1)); then
  usage
  exit 2
fi
case "$1" in
  absent | present) ;;
  *)
    usage
    exit 2
    ;;
esac
tmp_dir="$(mktemp --directory)"
trap 'rm --recursive --force -- "${tmp_dir}"' EXIT

main "$@"
