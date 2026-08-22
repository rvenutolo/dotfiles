#!/usr/bin/env bash

# @description Fixture suite for .dev/check-pin-digest-provenance.sh. Builds a
# base tree and a head tree in a tempdir, drives the checker through its
# BASE_DIR_OVERRIDE / HEAD_DIR_OVERRIDE hooks, and asserts the exit code and,
# where it matters, the reported message.
#
# The gate is only useful if it stays sharp, so the cases are written against
# what the checker SHOULD do rather than what it currently does: a repoint
# fails, a genuine version bump passes, an added or removed pin passes, an
# unparsable pin shape dies loud rather than passing as a no-op, and a rename
# does not let a repoint slip through as an add plus a remove.
# @noargs
# @stdout one `ok` line per passing case, then a summary
# @stderr the diff between expected and actual for any failing case
# @exitcode 0 every case passed
# @exitcode 1 one or more cases failed

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

SCRIPT_DIR="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"
readonly SCRIPT_DIR
# Absolute, because the git-ref cases below cd into a scratch repo to run it.
readonly CHECKER="${SCRIPT_DIR}/check-pin-digest-provenance.sh"
# Deliberately hex-with-letters, not all digits: an all-digit fixture makes the
# uppercase/lowercase case below a no-op that silently tests nothing.
readonly SHA_A='a1b1c1d1e1f11111111111111111111111111111'
readonly SHA_B='a2b2c2d2e2f22222222222222222222222222222'
readonly SHA_C='a3b3c3d3e3f33333333333333333333333333333'

PAIR_BASE=''
PAIR_HEAD=''
declare -i PASSED=0
declare -i FAILED=0
TMP_ROOT=''

function cleanup() {
  [[ -n "${TMP_ROOT}" ]] && rm --recursive --force -- "${TMP_ROOT}"
}

# @description Write a minimal workflow file containing the given `uses:` lines.
# @arg $1 tree root
# @arg $2 workflow file name (e.g. ci.yaml)
# @arg $@ remaining args are literal `uses:` values with their trailing comment
function write_workflow() {
  local -r root="$1"
  local -r name="$2"
  shift 2
  local uses
  mkdir --parents -- "${root}/.github/workflows"
  {
    printf 'name: T\non:\n  push:\njobs:\n  j:\n    runs-on: ubuntu-latest\n    steps:\n'
    for uses in "$@"; do
      printf '      - uses: %s\n' "${uses}"
    done
  } > "${root}/.github/workflows/${name}"
}

# @description Write a minimal .pre-commit-config.yaml from `url<TAB>revline`
# pairs, where revline is the literal text placed after `rev: `.
# @arg $1 tree root
# @arg $@ remaining args are `url|revline` strings
function write_pre_commit() {
  local -r root="$1"
  shift
  local entry url revline
  {
    printf 'repos:\n'
    for entry in "$@"; do
      url="${entry%%|*}"
      revline="${entry#*|}"
      printf '  - repo: %s\n    rev: %s\n    hooks:\n      - id: h\n' "${url}" "${revline}"
    done
  } > "${root}/.pre-commit-config.yaml"
}

# @description Run the checker against a base/head pair and assert the outcome.
# @arg $1 case name
# @arg $2 expected exit code
# @arg $3 substring the combined output must contain (empty to skip the check)
# @arg $4 base tree root
# @arg $5 head tree root
function assert_case() {
  local -r name="$1"
  local -r want_code="$2"
  local -r want_text="$3"
  local -r base="$4"
  local -r head="$5"
  local output
  local -i code=0
  output="$(BASE_DIR_OVERRIDE="${base}" HEAD_DIR_OVERRIDE="${head}" \
    bash "${CHECKER}" 2>&1)" || code=$?
  if ((code != want_code)); then
    printf 'FAIL %s: exit %d, want %d\n%s\n' "${name}" "${code}" "${want_code}" "${output}" >&2
    FAILED=$((FAILED + 1))
    return 0
  fi
  if [[ -n "${want_text}" && "${output}" != *"${want_text}"* ]]; then
    printf 'FAIL %s: output missing %q\n%s\n' "${name}" "${want_text}" "${output}" >&2
    FAILED=$((FAILED + 1))
    return 0
  fi
  printf 'ok %s\n' "${name}"
  PASSED=$((PASSED + 1))
}

# @description Create a fresh base/head tree pair for one case.
#
# The roots land in globals rather than on stdout because a case would
# otherwise have to read two lines out of a command substitution, and a
# `read` that silently returns nothing would leave the case comparing two
# empty paths — which passes.
# @arg $1 case name, used as the directory name
# @sets PAIR_BASE PAIR_HEAD
function new_pair() {
  local -r name="$1"
  PAIR_BASE="${TMP_ROOT}/${name}/base"
  PAIR_HEAD="${TMP_ROOT}/${name}/head"
  mkdir --parents -- "${PAIR_BASE}" "${PAIR_HEAD}"
}

# @description An unchanged tree must pass and report what it scanned.
function case_clean() {
  new_pair 'clean'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${head}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_pre_commit "${base}" "https://github.com/x/y|${SHA_B}  # frozen: v1.0.0"
  write_pre_commit "${head}" "https://github.com/x/y|${SHA_B}  # frozen: v1.0.0"
  assert_case 'clean tree passes' 0 '2 pin(s) across 2 file(s)' "${base}" "${head}"
}

# @description The core case: SHA moves, version label does not.
function case_action_repoint() {
  new_pair 'action-repoint'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${head}" 'ci.yaml' "actions/checkout@${SHA_B} # v7.0.1"
  assert_case 'action repoint fails' 1 'pin repointed under unchanged version: actions/checkout (v7.0.1)' \
    "${base}" "${head}"
}

# @description A real release: both the SHA and the label move. Must pass.
function case_action_version_bump() {
  new_pair 'action-bump'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${head}" 'ci.yaml' "actions/checkout@${SHA_B} # v7.0.2"
  assert_case 'action version bump passes' 0 '' "${base}" "${head}"
}

# @description A pre-commit rev repoint under an unchanged `# frozen:` label.
function case_pre_commit_repoint() {
  new_pair 'rev-repoint'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_pre_commit "${base}" "https://github.com/gitleaks/gitleaks|${SHA_A}  # frozen: v8.30.1"
  write_pre_commit "${head}" "https://github.com/gitleaks/gitleaks|${SHA_B}  # frozen: v8.30.1"
  assert_case 'pre-commit rev repoint fails' 1 \
    'pin repointed under unchanged version: https://github.com/gitleaks/gitleaks (v8.30.1)' \
    "${base}" "${head}"
}

# @description A pre-commit rev bump that also moves the label. Must pass.
function case_pre_commit_bump() {
  new_pair 'rev-bump'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_pre_commit "${base}" "https://github.com/gitleaks/gitleaks|${SHA_A}  # frozen: v8.30.1"
  write_pre_commit "${head}" "https://github.com/gitleaks/gitleaks|${SHA_B}  # frozen: v8.31.0"
  assert_case 'pre-commit rev bump passes' 0 '' "${base}" "${head}"
}

# @description Adding and removing pins are one-sided keys, not repoints.
function case_add_and_remove() {
  new_pair 'add-remove'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${head}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1" "actions/cache@${SHA_C} # v6.1.0"
  assert_case 'added pin passes' 0 '' "${base}" "${head}"
  assert_case 'removed pin passes' 0 '' "${head}" "${base}"
}

# @description The reason the key omits the filename: a workflow renamed in the
# same PR that repoints a pin must still be caught, not read as an add plus a
# remove in two different files.
function case_rename_hides_repoint() {
  new_pair 'rename'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${head}" 'build.yaml' "actions/checkout@${SHA_B} # v7.0.1"
  assert_case 'rename does not hide a repoint' 1 'pin repointed under unchanged version' "${base}" "${head}"
}

# @description The same pin in two workflows, repointed in only one of them.
# The key's SHA set differs between sides, so it must still fail.
function case_partial_repoint() {
  new_pair 'partial'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${base}" 'link.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${head}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  write_workflow "${head}" 'link.yaml' "actions/checkout@${SHA_B} # v7.0.1"
  assert_case 'repoint in one of two files fails' 1 'pin repointed under unchanged version' "${base}" "${head}"
}

# @description A local composite action has no upstream tag to repoint and must
# not be mistaken for an unparsable pin.
function case_local_action_ignored() {
  new_pair 'local-action'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' './.github/actions/setup'
  write_workflow "${head}" 'ci.yaml' './.github/actions/setup'
  assert_case 'local composite action ignored' 0 '0 pin(s)' "${base}" "${head}"
}

# @description A pin shape the gate cannot parse is a silent coverage gap, so
# it must die loud (exit 2) rather than compare as a no-op.
function case_unparsable_pin_dies() {
  new_pair 'unparsable'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' 'actions/checkout@v7'
  write_workflow "${head}" 'ci.yaml' 'actions/checkout@v7'
  assert_case 'tag-shaped pin dies loud' 2 'unrecognized uses: pin shape' "${base}" "${head}"
}

# @description A rev with no `# frozen:` comment carries no version to key on,
# so it must die rather than go silently uncovered.
function case_rev_without_frozen_dies() {
  new_pair 'rev-no-frozen'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_pre_commit "${base}" "https://github.com/x/y|${SHA_A}"
  write_pre_commit "${head}" "https://github.com/x/y|${SHA_A}"
  assert_case 'rev without frozen comment dies loud' 2 "without a 40-hex SHA and '# frozen:' version" \
    "${base}" "${head}"
}

# @description A floating-major label cannot be judged offline, so a moved SHA
# under one is reported rather than silently allowed.
function case_floating_major_reported() {
  new_pair 'floating'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A} # v7"
  write_workflow "${head}" 'ci.yaml' "actions/checkout@${SHA_B} # v7"
  assert_case 'floating-major move is reported' 1 'floating-major label outside this gate' "${base}" "${head}"
}

# @description A pin whose SHA is written in upper case is the same pin; case
# must not read as a repoint.
function case_sha_case_insensitive() {
  new_pair 'sha-case'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  write_workflow "${base}" 'ci.yaml' "actions/checkout@${SHA_A^^} # v7.0.1"
  write_workflow "${head}" 'ci.yaml' "actions/checkout@${SHA_A} # v7.0.1"
  assert_case 'SHA letter case is not a repoint' 0 '' "${base}" "${head}"
}

# @description The `entry:` regex in this repo's own no-unpinned-precommit-revs
# hook contains the text `rev:`. It must not be parsed as a pin line.
function case_entry_regex_not_a_pin() {
  new_pair 'entry-regex'
  local -r base="${PAIR_BASE}"
  local -r head="${PAIR_HEAD}"
  local content
  content="$(
    printf 'repos:\n  - repo: local\n    hooks:\n      - id: no-unpinned\n'
    printf "        entry: '^\\\\s*rev:(?![ \\\\t]*[0-9a-fA-F]{40})'\n"
  )"
  printf '%s\n' "${content}" > "${base}/.pre-commit-config.yaml"
  printf '%s\n' "${content}" > "${head}/.pre-commit-config.yaml"
  assert_case "a hook's entry: regex is not a pin" 0 '0 pin(s)' "${base}" "${head}"
}

# @description Build a scratch git repo whose HEAD commit holds the given
# workflow pin and pre-commit pin, and echo its path. The worktree is left
# matching HEAD; a caller mutates it to form the head side.
# @arg $1 directory name under TMP_ROOT
# @arg $2 `uses:` value to commit
# @arg $3 pre-commit `url|revline` entry to commit
# @stdout the repo path
function new_git_repo() {
  local -r name="$1"
  local -r uses="$2"
  local -r entry="$3"
  local -r repo="${TMP_ROOT}/${name}"
  mkdir --parents -- "${repo}"
  git -C "${repo}" init --quiet --initial-branch=main
  write_workflow "${repo}" 'ci.yaml' "${uses}"
  write_pre_commit "${repo}" "${entry}"
  git -C "${repo}" add --all
  # Identity and signing forced off so the suite does not depend on (or trip
  # over) the developer's global git config.
  git -C "${repo}" \
    -c user.name='T' -c user.email='t@example.invalid' -c commit.gpgsign=false \
    commit --quiet --message='base'
  printf '%s\n' "${repo}"
}

# @description Run the checker against a real git ref rather than the
# BASE_DIR_OVERRIDE fixture path, and assert the outcome. This is the path CI
# uses — `git ls-tree` for the file list and `git show` for content — and
# nothing else in this suite reaches it.
# @arg $1 case name
# @arg $2 expected exit code
# @arg $3 substring the combined output must contain (empty to skip)
# @arg $4 repo path, with HEAD as base and the worktree as head
function assert_git_case() {
  local -r name="$1"
  local -r want_code="$2"
  local -r want_text="$3"
  local -r repo="$4"
  local output
  local -i code=0
  output="$(cd -- "${repo}" && BASE_REF='HEAD' bash "${CHECKER}" 2>&1)" || code=$?
  if ((code != want_code)); then
    printf 'FAIL %s: exit %d, want %d\n%s\n' "${name}" "${code}" "${want_code}" "${output}" >&2
    FAILED=$((FAILED + 1))
    return 0
  fi
  if [[ -n "${want_text}" && "${output}" != *"${want_text}"* ]]; then
    printf 'FAIL %s: output missing %q\n%s\n' "${name}" "${want_text}" "${output}" >&2
    FAILED=$((FAILED + 1))
    return 0
  fi
  printf 'ok %s\n' "${name}"
  PASSED=$((PASSED + 1))
}

# @description An unmodified worktree against its own HEAD must pass, proving
# the git-ref file list and content reads both work.
function case_git_ref_clean() {
  local repo
  repo="$(new_git_repo 'git-clean' "actions/checkout@${SHA_A} # v7.0.1" \
    "https://github.com/x/y|${SHA_B}  # frozen: v1.0.0")"
  assert_git_case 'git-ref base: clean tree passes' 0 '2 pin(s) across 2 file(s)' "${repo}"
}

# @description A pre-commit rev repoint seen through the git-ref path. Uses the
# pre-commit file specifically: if the git-side file list ever stops treating
# .pre-commit-config.yaml as scanned, its base content reads as absent, the pin
# goes one-sided, and the repoint passes — which this case is here to catch.
function case_git_ref_repoint() {
  local repo
  repo="$(new_git_repo 'git-repoint' "actions/checkout@${SHA_A} # v7.0.1" \
    "https://github.com/x/y|${SHA_B}  # frozen: v1.0.0")"
  write_pre_commit "${repo}" "https://github.com/x/y|${SHA_C}  # frozen: v1.0.0"
  assert_git_case 'git-ref base: pre-commit repoint fails' 1 \
    'pin repointed under unchanged version: https://github.com/x/y (v1.0.0)' "${repo}"
}

# @description An unresolvable base ref is an operational failure, never a
# clean verdict: a gate that cannot read the base must not report "OK".
function case_git_ref_missing_dies() {
  local repo
  repo="$(new_git_repo 'git-missing' "actions/checkout@${SHA_A} # v7.0.1" \
    "https://github.com/x/y|${SHA_B}  # frozen: v1.0.0")"
  local output
  local -i code=0
  output="$(cd -- "${repo}" && BASE_REF='refs/remotes/origin/nope' bash "${CHECKER}" 2>&1)" || code=$?
  if ((code == 2)) && [[ "${output}" == *'cannot resolve'* ]]; then
    printf 'ok git-ref base: unresolvable ref dies loud\n'
    PASSED=$((PASSED + 1))
  else
    printf 'FAIL git-ref base: unresolvable ref dies loud: exit %d\n%s\n' "${code}" "${output}" >&2
    FAILED=$((FAILED + 1))
  fi
}

function main() {
  [[ -x "${CHECKER}" ]] || {
    printf 'checker not executable: %s\n' "${CHECKER}" >&2
    exit 1
  }
  TMP_ROOT="$(mktemp --directory)"
  trap cleanup EXIT

  case_clean
  case_action_repoint
  case_action_version_bump
  case_pre_commit_repoint
  case_pre_commit_bump
  case_add_and_remove
  case_rename_hides_repoint
  case_partial_repoint
  case_local_action_ignored
  case_unparsable_pin_dies
  case_rev_without_frozen_dies
  case_floating_major_reported
  case_sha_case_insensitive
  case_entry_regex_not_a_pin
  case_git_ref_clean
  case_git_ref_repoint
  case_git_ref_missing_dies

  printf '\n%d passed, %d failed\n' "${PASSED}" "${FAILED}"
  ((FAILED == 0))
}

main "$@"
