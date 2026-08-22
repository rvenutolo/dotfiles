#!/usr/bin/env bash

# @description Lint: a pinned SHA may not move under an unchanged version
# label. Diffs every GitHub Actions pin (`uses: owner/repo@<sha> # <version>`)
# in .github/workflows/ and every pre-commit hook pin
# (`rev: <sha>  # frozen: <version>`) in .pre-commit-config.yaml against the
# base ref. A SHA that changed while its version label did not is a repointed
# released tag — the digest-repoint supply-chain class — and fails.
#
# Why this exists as a separate gate: `minimumReleaseAge` does not catch it.
# Renovate ages a `digest` update against the release timestamp of the matched
# version, and that version was released months ago, so a repointed tag clears
# the quarantine instantly. Renovate's own docs say so outright: "Datasources
# whose timestamps reflect when the matched version was first released (such as
# github-tags for digest-pinned GitHub Actions) cannot detect re-published
# content." With .github/renovate.json5 set to automerge everything, this
# PR-time diff is the only automated gate standing on that path.
#
# Pre-commit revs are covered for a stronger reason than the actions are: a
# hook executes on the developer's machine at commit time with access to
# ~/.keys and ~/.ssh, where an action only ever runs in a disposable runner.
#
# Deliberately offline — no GitHub API calls, so this stays fast and needs no
# token. One consequence: a pin naming an annotated tag OBJECT and a pin naming
# the commit that tag points at are the same release one dereference apart, but
# they read here as a SHA that moved under an unchanged label and fail. That is
# a loud false positive, not a silent gap; confirm upstream and land the
# correction as its own commit. Renovate always writes the dereferenced commit,
# so only a hand-edit can produce it.
#
# Comparison is keyed on (pin identity, version label), NOT on the file the pin
# lives in: a pin's identity is what it points at, not which file names it, so
# a workflow rename plus a repoint in the same PR still lands on one key
# instead of reading as an independent add + remove that skips the SHA compare.
#
# A pin shape this script cannot parse is a pin silently outside its coverage,
# so unrecognized shapes exit 2 rather than passing as a no-op comparison.
#
# Must be run from the repo root. Self-tested by
# .dev/check-pin-digest-provenance.test.sh, which drives it through the
# BASE_DIR_OVERRIDE / HEAD_DIR_OVERRIDE hooks below.
# @noargs
# @stdout one-line pass banner with the counts scanned
# @stderr one `FAIL:` line per violation, or an operational error
# @exitcode 0 no pin moved under an unchanged version label
# @exitcode 1 one or more pins were repointed
# @exitcode 2 operational error, or a pin shape outside this gate's coverage

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

# Associative arrays (4.0), mapfile (4.0), and the `local -n` nameref used by
# index_tuples (4.3) all postdate the bash 3.2 that ships as /bin/bash on
# macOS. Fail with a readable message rather than a parse error.
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3))); then
  printf 'pin-digest-provenance: bash 4.3+ required (found %s)\n' "${BASH_VERSION}" >&2
  exit 2
fi

# Git ref holding the content to diff against. Overridable so CI can point at
# the PR's own base branch rather than assuming main.
readonly BASE_REF="${BASE_REF:-origin/main}"
# Test-only: read the base/head side from a directory instead of a git ref.
readonly BASE_DIR="${BASE_DIR_OVERRIDE:-}"
readonly HEAD_DIR="${HEAD_DIR_OVERRIDE:-.}"
readonly PRE_COMMIT_FILE='.pre-commit-config.yaml'

# @description Print an operational error and exit 2. Deliberately distinct
# from a violation (exit 1): "this gate could not run" and "this gate found a
# repoint" are different facts and must never collapse to one exit code.
# @arg $@ message to print
# @stderr the message
# @exitcode 2 always
function die_op() {
  printf 'pin-digest-provenance: %s\n' "$*" >&2
  exit 2
}

# @description True if a repo-relative path is one this gate scans: a workflow
# YAML directly under .github/workflows/, or the pre-commit config. One
# predicate shared by the head-side glob and the base-side git-ls-tree scan, so
# the two sides cannot drift on what counts as a scanned file.
# @arg $1 path relative to a scan root
# @exitcode 0 the path is scanned
# @exitcode 1 the path is not scanned
function is_scanned_file() {
  local -r path="$1"
  [[ "${path}" =~ ^\.github/workflows/[^/]+\.ya?ml$ ]] && return 0
  [[ "${path}" == "${PRE_COMMIT_FILE}" ]] && return 0
  return 1
}

# @description Emit the scanned file list (paths relative to the given root)
# for a real directory root. Used for the head side always, and for the base
# side when BASE_DIR_OVERRIDE points at a directory instead of a git ref.
# @arg $1 root directory
# @stdout one repo-relative path per line
function scanned_files_under() {
  local -r root="$1"
  local -a candidates=()
  local workflow rel
  shopt -s nullglob
  candidates=("${root}/.github/workflows/"*.yaml "${root}/.github/workflows/"*.yml)
  shopt -u nullglob
  for workflow in "${candidates[@]}"; do
    rel="${workflow#"${root}"/}"
    if is_scanned_file "${rel}"; then
      printf '%s\n' "${rel}"
    fi
  done
  if [[ -f "${root}/${PRE_COMMIT_FILE}" ]]; then
    printf '%s\n' "${PRE_COMMIT_FILE}"
  fi
}

# Base-side scanned file list, resolved once and cached so base_files() and
# base_content() cannot disagree about what "is in base". A file this set says
# is absent gets a benign empty read; a file it says is present that then fails
# to read dies loud.
declare -A BASE_FILE_SET=()
declare -i BASE_FILE_SET_LOADED=0

# @description Resolve the base-side file list once via a single git ls-tree.
# An ls-tree failure dies loud rather than yielding an empty list: an empty
# base list would make every base pin read as "absent", which turns a real
# repoint into a one-sided key, which passes silently.
# @noargs
# @sets BASE_FILE_SET BASE_FILE_SET_LOADED
function load_base_file_list() {
  ((BASE_FILE_SET_LOADED)) && return 0
  local tree_output
  local -a tree_paths=()
  local path
  # Captured before mapfile rather than piped into it: mapfile reading from a
  # process substitution returns 0 even when the producer died, so a failed
  # git ls-tree would arrive here as an empty (and therefore "clean") base.
  tree_output="$(git ls-tree -r --name-only "${BASE_REF}")" \
    || die_op "git ls-tree failed for ${BASE_REF}"
  mapfile -t tree_paths <<< "${tree_output}"
  for path in "${tree_paths[@]}"; do
    if is_scanned_file "${path}"; then
      BASE_FILE_SET["${path}"]=1
    fi
  done
  BASE_FILE_SET_LOADED=1
}

# @description Emit the base-side scanned file list. Deliberately independent
# of the head-side list: a file renamed between base and head must still be
# discovered under its own (old) base-side path, so the rename lands as a SHA
# comparison on a shared key rather than a file that "is absent from base".
# @noargs
# @stdout one repo-relative path per line
function base_files() {
  if [[ -n "${BASE_DIR}" ]]; then
    scanned_files_under "${BASE_DIR}"
    return 0
  fi
  load_base_file_list
  local path
  for path in "${!BASE_FILE_SET[@]}"; do
    printf '%s\n' "${path}"
  done
}

# @description Print a file's base-side content; empty output when the file is
# absent from base. A file already proved present that then fails to read dies
# loud — absent and unreadable are different facts and must not both pass.
# @arg $1 path relative to the repo root
# @stdout the file content, or nothing when the file is absent in base
function base_content() {
  local -r file="$1"
  local content
  if [[ -n "${BASE_DIR}" ]]; then
    [[ -e "${BASE_DIR}/${file}" ]] || return 0
    [[ -f "${BASE_DIR}/${file}" ]] || die_op "not a regular file: ${BASE_DIR}/${file}"
    if ! content="$(cat -- "${BASE_DIR}/${file}" 2>&1)"; then
      die_op "cannot read ${BASE_DIR}/${file}: ${content}"
    fi
    printf '%s' "${content}"
    return 0
  fi
  load_base_file_list
  [[ -n "${BASE_FILE_SET[${file}]+set}" ]] || return 0
  if ! content="$(git show "${BASE_REF}:${file}" 2>&1)"; then
    die_op "git show failed for ${BASE_REF}:${file}: ${content}"
  fi
  printf '%s' "${content}"
}

# @description Emit `identity|version|sha` tuples for the GitHub Actions pins
# in one workflow's content on stdin. A `uses:` line carrying an `@` that the
# strict pin pattern does not match is a coverage gap, not a pass, so it dies.
# @arg $1 file path, for diagnostics
# @stdout one `identity|version|sha` tuple per pin
function extract_action_pins() {
  local -r file="$1"
  local line value
  local -i line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "${line}" =~ uses:[[:space:]]+([A-Za-z0-9._/-]+)@([0-9a-fA-F]{40})[[:space:]]*#[[:space:]]*([^[:space:]]+) ]]; then
      printf '%s|%s|%s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[2],,}"
      continue
    fi
    [[ "${line}" =~ ^[[:space:]]*-?[[:space:]]*uses:[[:space:]] ]] || continue
    # The strict pattern above missed this `uses:` line. Isolate its value to
    # tell a local composite-action ref (`./...`, no upstream to repoint) from
    # an unrecognized pin shape that this gate would otherwise skip in silence.
    if [[ "${line}" =~ uses:[[:space:]]*[\"\']?([^[:space:]\"\']*) ]]; then
      value="${BASH_REMATCH[1]}"
    else
      value=''
    fi
    if [[ -z "${value}" || "${value}" == .* ]]; then
      continue
    fi
    [[ "${value}" == *@* ]] || continue
    die_op "unrecognized uses: pin shape at ${file}:${line_num}: ${line}"
  done
}

# @description Emit `identity|version|sha` tuples for the pre-commit hook pins
# in .pre-commit-config.yaml on stdin. Identity is the `- repo:` URL the `rev:`
# belongs to. A `rev:` without a 40-hex SHA and a `# frozen:` version comment
# carries no label to key on, so it dies rather than going uncovered.
# @arg $1 file path, for diagnostics
# @stdout one `identity|version|sha` tuple per pin
function extract_pre_commit_pins() {
  local -r file="$1"
  local line repo=''
  local -i line_num=0
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ "${line}" =~ ^[[:space:]]*-[[:space:]]+repo:[[:space:]]+([^[:space:]]+) ]]; then
      repo="${BASH_REMATCH[1]}"
      continue
    fi
    # Anchored at line start so a hook's own `entry:` regex mentioning `rev:`
    # (the no-unpinned-precommit-revs hook contains one) is never mistaken for
    # a pin line.
    [[ "${line}" =~ ^[[:space:]]*rev:[[:space:]] ]] || continue
    if [[ "${line}" =~ ^[[:space:]]*rev:[[:space:]]+([0-9a-fA-F]{40})[[:space:]]*#[[:space:]]*frozen:[[:space:]]*([^[:space:]]+) ]]; then
      [[ -n "${repo}" ]] || die_op "rev: with no enclosing repo: at ${file}:${line_num}"
      printf '%s|%s|%s\n' "${repo}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[1],,}"
      continue
    fi
    die_op "rev: without a 40-hex SHA and '# frozen:' version at ${file}:${line_num}: ${line}"
  done
}

# @description Emit `identity|version|sha` tuples for one file's content on
# stdin, dispatching on which kind of file it is.
# @arg $1 file path relative to the repo root
# @stdout one `identity|version|sha` tuple per pin
function extract_pins() {
  local -r file="$1"
  if [[ "${file}" == "${PRE_COMMIT_FILE}" ]]; then
    extract_pre_commit_pins "${file}"
  else
    extract_action_pins "${file}"
  fi
}

# @description Emit every pin tuple on one side of the diff.
# @arg $1 side to collect: `head` or `base`
# @stdout one `identity|version|sha` tuple per pin
function collect_tuples() {
  local -r side="$1"
  local file_list file content
  if [[ "${side}" == 'head' ]]; then
    file_list="$(scanned_files_under "${HEAD_DIR}")"
  else
    file_list="$(base_files)"
  fi
  while IFS= read -r file; do
    [[ -n "${file}" ]] || continue
    # Captured on its own line rather than nested inside the extract_pins
    # here-string: a die_op inside a nested command substitution would exit
    # only that subshell, and extract_pins would then read empty stdin and
    # return 0 — turning a loud coverage gap into a silent pass.
    if [[ "${side}" == 'head' ]]; then
      content="$(cat -- "${HEAD_DIR}/${file}")"
    else
      content="$(base_content "${file}")"
    fi
    extract_pins "${file}" <<< "${content}"
  done <<< "${file_list}"
}

# @description Index a tuple block into an associative array, keyed on
# `identity|version` with a newline-joined SHA set as the value. Splitting on
# the LAST `|` is safe because neither an action path nor a repo URL nor a
# version label can contain one.
# @arg $1 name of the associative array to populate
# @arg $2 newline-joined `identity|version|sha` tuple block
# @sets the named associative array
function index_tuples() {
  local -r map_name="$1"
  local -r tuples="$2"
  local -n map_ref="${map_name}"
  local tuple key sha
  while IFS= read -r tuple; do
    [[ -n "${tuple}" ]] || continue
    key="${tuple%|*}"
    sha="${tuple##*|}"
    map_ref["${key}"]+="${sha}"$'\n'
  done <<< "${tuples}"
}

# @description Normalize one key's recorded SHA set to sorted-unique lines.
# @arg $1 newline-joined SHA list, possibly with duplicates and a trailing blank
# @stdout one SHA per line, sorted and deduplicated
function normalize_shas() {
  local -r raw="$1"
  [[ -n "${raw}" ]] || return 0
  printf '%s' "${raw}" | sort --unique
}

# @description Render a SHA set as a single comma-separated line for a report.
# @arg $1 newline-separated SHA set
# @stdout the SHAs joined with commas
function join_shas() {
  local -r shas="$1"
  local joined="${shas//$'\n'/,}"
  printf '%s' "${joined%,}"
}

function main() {
  if [[ -z "${BASE_DIR}" ]]; then
    git rev-parse --verify --quiet "${BASE_REF}^{commit}" > /dev/null \
      || die_op "cannot resolve ${BASE_REF} (is it fetched?)"
    # Resolved up front, in the main shell, so a broken checkout surfaces once
    # as its own operational error rather than as a per-file symptom partway
    # through the comparison.
    load_base_file_list
  fi

  local head_tuples base_tuples
  head_tuples="$(collect_tuples 'head')"
  base_tuples="$(collect_tuples 'base')"

  local -A head_map=()
  local -A base_map=()
  index_tuples head_map "${head_tuples}"
  index_tuples base_map "${base_tuples}"

  local -A all_keys=()
  local key
  for key in "${!head_map[@]}"; do
    all_keys["${key}"]=1
  done
  for key in "${!base_map[@]}"; do
    all_keys["${key}"]=1
  done

  local -i violations=0
  local base_shas head_shas identity version
  for key in "${!all_keys[@]}"; do
    base_shas="$(normalize_shas "${base_map[${key}]:-}")"
    head_shas="$(normalize_shas "${head_map[${key}]:-}")"
    # A key present on only one side is a pin (or a version) added or removed,
    # not a repoint. Genuine version bumps ride minimumReleaseAge instead.
    [[ -n "${base_shas}" && -n "${head_shas}" ]] || continue
    [[ "${base_shas}" == "${head_shas}" ]] && continue
    identity="${key%|*}"
    version="${key##*|}"
    if [[ "${version}" =~ ^v?[0-9]+$ ]]; then
      # A floating-major label legitimately retargets across patch releases, so
      # a moved SHA under it is not by itself proof of a repoint. Telling the
      # two apart needs an upstream reachability probe, which this offline gate
      # does not do — so it reports the shape rather than guessing. CLAUDE.md
      # requires exact `# vX.Y.Z` labels; pin one and this stops firing.
      printf 'FAIL: floating-major label outside this gate: %s (%s): %s -> %s\n' \
        "${identity}" "${version}" "$(join_shas "${base_shas}")" "$(join_shas "${head_shas}")" >&2
    else
      printf 'FAIL: pin repointed under unchanged version: %s (%s): %s -> %s\n' \
        "${identity}" "${version}" "$(join_shas "${base_shas}")" "$(join_shas "${head_shas}")" >&2
    fi
    violations=1
  done

  if ((violations != 0)); then
    printf 'pin digest provenance check FAILED — a pin moved under an unchanged version label.\n' >&2
    printf 'A repointed released tag is the digest-repoint supply-chain class: the SHA changed but\n' >&2
    printf 'the version did not, which no legitimate release does. Review upstream before unblocking.\n' >&2
    exit 1
  fi

  # The banner reports the work done, not just the verdict: a clean run that
  # scanned nothing and a clean run that scanned everything are the same
  # verdict but very different facts, and only the counts separate them.
  local file_list
  file_list="$(scanned_files_under "${HEAD_DIR}")"
  local -i pin_count=0
  local -i file_count=0
  if [[ -n "${head_tuples}" ]]; then
    pin_count="$(printf '%s\n' "${head_tuples}" | wc --lines)"
  fi
  if [[ -n "${file_list}" ]]; then
    file_count="$(printf '%s\n' "${file_list}" | wc --lines)"
  fi
  printf 'pin digest provenance OK: %d pin(s) across %d file(s)\n' "${pin_count}" "${file_count}"
}

main "$@"
