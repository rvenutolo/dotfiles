#!/usr/bin/env bash

# @description Check that every `paths.*` entry in .chezmoidata.yaml exists
# under $HOME (entries are home-relative; some are files, some are dirs, so
# plain existence is tested), and that every `git_repos` entry has a matching
# `paths.<name>_dir` key (the invariant `topgrade.toml.tmpl`'s `{{ fail }}`
# guard depends on at render time). Must be run from the repo root.
#
# The path-existence check is machine-specific (it stats real paths under the
# current $HOME) and cannot run on a CI runner, which has no dotfiles applied.
# The git_repos cross-check is pure data (.chezmoidata.yaml only) and is
# portable, so `--git-repos-only` runs just that half — this is what the
# pre-commit hook (and therefore CI) invokes. Plain `just check-paths` (no
# flag) still runs both, for local use.
# @arg $1 optional; `--git-repos-only` to skip the $HOME existence check
# @stderr one `missing: <abs-path> (<key>)` line per missing path
# @stderr one `git_repos entry has no matching paths.<name>_dir: <name>` line
#   per unmatched git_repos entry
# @exitcode 0 all checks pass
# @exitcode 1 one or more paths are missing or git_repos entries are unmatched

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

readonly DATA_FILE='.chezmoidata.yaml'

# @description Verify every `paths.*` entry exists under $HOME.
# @stderr one `missing: <abs-path> (<key>)` line per missing entry
# @exitcode 0 all paths exist
# @exitcode 1 one or more paths are missing
function check_paths_exist() {
  local -a entries
  local entry
  local key
  local value
  local missing=0
  mapfile -t entries < <(yq --output-format=tsv '.paths | to_entries | map([.key, .value]) | .[]' "${DATA_FILE}")
  for entry in "${entries[@]}"; do
    key="${entry%%$'\t'*}"
    value="${entry#*$'\t'}"
    if [[ ! -e "${HOME}/${value}" ]]; then
      printf 'missing: %s (%s)\n' "${HOME}/${value}" "${key}" >&2
      missing=1
    fi
  done
  return "${missing}"
}

# @description Verify every `git_repos` entry has a matching `paths.<name>_dir`
# key. `topgrade.toml.tmpl` ranges over `git_repos` and looks up
# `paths.<name>_dir` for each; a mismatch fails template render at apply time.
# This check catches the mismatch pre-merge instead.
# @stderr one `git_repos entry has no matching paths.<name>_dir: <name>` line
#   per unmatched entry
# @exitcode 0 every git_repos entry has a matching paths.<name>_dir key
# @exitcode 1 one or more git_repos entries have no matching paths key
function check_git_repos_have_paths() {
  local -a repo_names
  local -a path_keys
  local repo
  local missing=0
  mapfile -t repo_names < <(yq '.git_repos[]' "${DATA_FILE}")
  mapfile -t path_keys < <(yq '.paths | keys | .[]' "${DATA_FILE}")
  for repo in "${repo_names[@]}"; do
    if ! printf '%s\n' "${path_keys[@]}" | grep --quiet --line-regexp --fixed-strings "${repo}_dir"; then
      printf 'git_repos entry has no matching paths.%s_dir: %s\n' "${repo}" "${repo}" >&2
      missing=1
    fi
  done
  return "${missing}"
}

function main() {
  local status=0
  local -r mode="${1:-}"

  case "${mode}" in
    --git-repos-only) ;;
    '')
      check_paths_exist || status=1
      ;;
    *)
      printf 'usage: %s [--git-repos-only]\n' "${0##*/}" >&2
      exit 2
      ;;
  esac
  check_git_repos_have_paths || status=1

  exit "${status}"
}

main "$@"
