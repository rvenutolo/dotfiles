#!/usr/bin/env bash

# @description Test suite for dot_local/bin/executable_chezmoi-claude. Runs the
# wrapper from the source tree against a stub `chezmoi` that prints PAYLOAD_RAN
# followed by its arguments, so the real chezmoi is never invoked and the
# wrapper's refusal to run without its config file is observable: a real
# `chezmoi --config <missing file>` would silently fall back to the default
# dotfiles source and $HOME.
# @noargs
# @stdout one `ok` / `FAIL` line per case, then a summary
# @exitcode 0 every case passed
# @exitcode 1 one or more cases failed

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

SCRIPT_DIR="$(cd -- "${BASH_SOURCE[0]%/*}" && pwd)"
readonly SCRIPT_DIR
readonly WRAPPER="${SCRIPT_DIR}/../dot_local/bin/executable_chezmoi-claude"
readonly MARKER='PAYLOAD_RAN'

TMP_ROOT=''
declare -i PASSED=0
declare -i FAILED=0
OUT=''
ERR=''
STATUS=0

function cleanup() {
  if [[ -n "${TMP_ROOT}" ]]; then
    rm --recursive --force -- "${TMP_ROOT}"
  fi
}

# @description Record one case result and print its line.
# @arg $1 name case name
# @arg $2 verdict 0 for pass, anything else for fail
# @arg $3 detail context printed on failure
function report() {
  local -r name="$1"
  local -r verdict="$2"
  local -r detail="$3"
  if [[ "${verdict}" == '0' ]]; then
    PASSED+=1
    printf 'ok   %s\n' "${name}"
  else
    FAILED+=1
    printf 'FAIL %s\n' "${name}"
    printf '     %s\n' "${detail}"
  fi
}

# @description Run the wrapper with a scratch environment, capturing stdout,
# stderr and exit status into OUT, ERR and STATUS.
# @arg $1 xdg value for XDG_CONFIG_HOME; '-' leaves it unset, empty sets it empty
# @arg $2 home value for HOME
# @arg $@ arguments for the wrapper
function run_wrapper() {
  local -r xdg="$1"
  local -r home="$2"
  shift 2
  local -a env_args=("HOME=${home}" "PATH=${TMP_ROOT}/bin:${PATH}")
  if [[ "${xdg}" != '-' ]]; then
    env_args+=("XDG_CONFIG_HOME=${xdg}")
  fi
  STATUS=0
  env --unset=XDG_CONFIG_HOME "${env_args[@]}" "${WRAPPER}" "$@" \
    > "${TMP_ROOT}/stdout" 2> "${TMP_ROOT}/stderr" || STATUS=$?
  OUT="$(< "${TMP_ROOT}/stdout")"
  ERR="$(< "${TMP_ROOT}/stderr")"
}

# @description Create a config file at the given XDG base.
# @arg $1 xdg XDG_CONFIG_HOME-style base directory
function make_config() {
  local -r xdg="$1"
  mkdir --parents -- "${xdg}/chezmoi-claude"
  : > "${xdg}/chezmoi-claude/chezmoi.toml"
}

# @description Install the stub chezmoi. `echo` prints PAYLOAD_RAN and the
# arguments, exiting with STUB_EXIT (default 0); `count` prints the argument count.
# @arg $1 mode echo or count
function write_stub() {
  local -r mode="$1"
  case "${mode}" in
    echo)
      cat > "${TMP_ROOT}/bin/chezmoi" << 'STUB'
#!/usr/bin/env bash
printf 'PAYLOAD_RAN'
printf ' %s' "$@"
printf '\n'
exit "${STUB_EXIT:-0}"
STUB
      ;;
    count)
      cat > "${TMP_ROOT}/bin/chezmoi" << 'STUB'
#!/usr/bin/env bash
printf '%s\n' "$#"
STUB
      ;;
  esac
  chmod +x "${TMP_ROOT}/bin/chezmoi"
}

# @description Run every case, print a summary, and exit non-zero on any failure.
# @noargs
function main() {
  TMP_ROOT="$(mktemp --directory)"
  trap cleanup EXIT
  mkdir --parents -- "${TMP_ROOT}/bin"
  write_stub echo

  local xdg="${TMP_ROOT}/absent/xdg"
  local config

  # 1. absent config: refuse, name the file, never reach chezmoi
  run_wrapper "${xdg}" "${TMP_ROOT}/home" diff
  config="${xdg}/chezmoi-claude/chezmoi.toml"
  if ((STATUS != 0)) && [[ "${ERR}" == *"${config}"* ]] && [[ "${OUT}${ERR}" != *"${MARKER}"* ]]; then
    report 'absent config refuses and names the file' 0 ''
  else
    report 'absent config refuses and names the file' 1 "status=${STATUS} out=${OUT} err=${ERR}"
  fi

  # 2. present config: exact argv
  xdg="${TMP_ROOT}/present/xdg"
  make_config "${xdg}"
  config="${xdg}/chezmoi-claude/chezmoi.toml"
  run_wrapper "${xdg}" "${TMP_ROOT}/home" diff
  if ((STATUS == 0)) && [[ "${OUT}" == "${MARKER} --config ${config} diff" ]]; then
    report 'present config runs chezmoi --config <file> diff' 0 ''
  else
    report 'present config runs chezmoi --config <file> diff' 1 "status=${STATUS} out=${OUT}"
  fi

  # 3. arguments pass through unchanged
  run_wrapper "${xdg}" "${TMP_ROOT}/home" edit 'a b' --flag
  if [[ "${OUT}" == "${MARKER} --config ${config} edit a b --flag" ]]; then
    # The stub joins with spaces; check the argument count separately so
    # "a b" is proven to be one argument.
    write_stub count
    run_wrapper "${xdg}" "${TMP_ROOT}/home" edit 'a b' --flag
    write_stub echo
    if [[ "${OUT}" == '5' ]]; then
      report 'arguments with spaces pass through unchanged' 0 ''
    else
      report 'arguments with spaces pass through unchanged' 1 "argc=${OUT}, want 5"
    fi
  else
    report 'arguments with spaces pass through unchanged' 1 "out=${OUT}"
  fi

  # 3b. no arguments: only --config <file>
  run_wrapper "${xdg}" "${TMP_ROOT}/home"
  if ((STATUS == 0)) && [[ "${OUT}" == "${MARKER} --config ${config}" ]]; then
    report 'zero arguments pass only --config <file>' 0 ''
  else
    report 'zero arguments pass only --config <file>' 1 "status=${STATUS} out=${OUT}"
  fi

  # 4. non-zero status propagates
  STUB_EXIT=7 run_wrapper "${xdg}" "${TMP_ROOT}/home" verify
  if ((STATUS == 7)); then
    report 'chezmoi exit status propagates' 0 ''
  else
    report 'chezmoi exit status propagates' 1 "status=${STATUS}, want 7"
  fi

  # 5. XDG_CONFIG_HOME unset: falls back to $HOME/.config
  local -r home="${TMP_ROOT}/fallback-home"
  make_config "${home}/.config"
  run_wrapper '-' "${home}" diff
  if ((STATUS == 0)) && [[ "${OUT}" == "${MARKER} --config ${home}/.config/chezmoi-claude/chezmoi.toml diff" ]]; then
    report 'unset XDG_CONFIG_HOME falls back to HOME/.config' 0 ''
  else
    report 'unset XDG_CONFIG_HOME falls back to HOME/.config' 1 "status=${STATUS} out=${OUT} err=${ERR}"
  fi

  # 6. XDG_CONFIG_HOME set but empty: also falls back to $HOME/.config
  run_wrapper '' "${home}" diff
  if ((STATUS == 0)) && [[ "${OUT}" == "${MARKER} --config ${home}/.config/chezmoi-claude/chezmoi.toml diff" ]]; then
    report 'empty XDG_CONFIG_HOME falls back to HOME/.config' 0 ''
  else
    report 'empty XDG_CONFIG_HOME falls back to HOME/.config' 1 "status=${STATUS} out=${OUT} err=${ERR}"
  fi

  printf '%d passed, %d failed\n' "${PASSED}" "${FAILED}"
  if ((FAILED != 0)); then
    exit 1
  fi
}

main "$@"
