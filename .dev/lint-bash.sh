#!/usr/bin/env bash

# @description Lint bash content: shellcheck + shfmt over plain scripts and the
# rendered output of chezmoi *.sh.tmpl scripts. With no args, lints every
# git-tracked bash file in the repo; with args, lints only the given files.
# Must be run from the repo root.
# @arg $@ optional file paths; defaults to all git-tracked bash files

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

readonly SHFMT_ARGS=(--indent 2 --case-indent --binary-next-line --space-redirects)

# @description Lint one file, rendering it first if it is a chezmoi template.
# @arg $1 path to a .sh/.bash/.sh.tmpl file
function lint_file() {
  local -r file="$1"
  local rendered
  case "${file}" in
    *.sh.tmpl)
      rendered="$(chezmoi execute-template < "${file}")"
      shellcheck --shell=bash - <<< "${rendered}"
      shfmt "${SHFMT_ARGS[@]}" --diff - <<< "${rendered}"
      ;;
    *)
      shellcheck "${file}"
      shfmt --list "${SHFMT_ARGS[@]}" --diff "${file}"
      ;;
  esac
}

function main() {
  local -a files
  local file
  if (($# > 0)); then
    files=("$@")
  else
    mapfile -t files < <(git ls-files -- '*.sh' '*.bash' '*.sh.tmpl')
  fi
  for file in "${files[@]}"; do
    # chezmoi symlink_ sources contain a link target path, not bash — skip.
    if [[ "${file##*/}" == symlink_* ]]; then
      continue
    fi
    lint_file "${file}"
  done
}

main "$@"
