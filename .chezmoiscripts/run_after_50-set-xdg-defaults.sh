#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR

# Set XDG default handlers for the browser, terminal, file manager, and editor.
#
# Runs on every apply (run_ prefix, not run_onchange_): the source variables
# ($BROWSER, $TERMINAL, $FILE_MANAGER, $VISUAL) are read at runtime from
# profile.sh, so a content-hash trigger on this script would miss changes to
# them. xdg-mime default is idempotent and fast, so the cost is trivial.
#
# Source variables are resolved by sourcing profile.sh in a subshell so the
# rest of this script's environment is not polluted by profile.sh side effects.
#
# Every failure mode is non-fatal: a missing variable, an unmapped binary, or
# an absent .desktop file logs a WARN and skips that role. This script must
# never fail an apply over a cosmetic default.

readonly PROFILE_SH="${HOME}/.config/profile.sh"

# MIME types to route to the chosen GUI editor.
# Deliberately excludes text/html and application/json (browser handles those).
readonly MIMES=(
  'application/javascript'
  'application/toml'
  'application/x-perl'
  'application/x-php'
  'application/x-ruby'
  'application/x-shellscript'
  'application/x-yaml'
  'application/xml'
  'application/yaml'
  'text/css'
  'text/csv'
  'text/javascript'
  'text/markdown'
  'text/plain'
  'text/tab-separated-values'
  'text/x-c'
  'text/x-c++hdr'
  'text/x-c++src'
  'text/x-chdr'
  'text/x-cmake'
  'text/x-csrc'
  'text/x-diff'
  'text/x-dockerfile'
  'text/x-go'
  'text/x-java'
  'text/x-java-source'
  'text/x-log'
  'text/x-makefile'
  'text/x-patch'
  'text/x-python'
  'text/x-ruby'
  'text/x-rust'
  'text/x-shellscript'
  'text/x-sql'
)

# XDG application search paths (mirrors xdg-mime's own lookup order).
readonly XDG_APP_DIRS=(
  "${HOME}/.local/share/applications"
  "${HOME}/.local/share/flatpak/exports/share/applications"
  '/var/lib/flatpak/exports/share/applications'
  '/usr/share/applications'
  "${HOME}/.nix-profile/share/applications"
)

# @description Log a message to stderr with a level prefix.
# @arg $1 level Severity label (INFO, WARN, ERROR).
# @arg $2 msg Message body.
function log() {
  local -r level="$1"
  local -r msg="$2"
  printf '[%s] %-5s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "${level}" "${msg}" >&2
}
function log::info() { log 'INFO' "$*"; }
function log::warn() { log 'WARN' "$*"; }
function log::err() { log 'ERROR' "$*"; }

# @description Read $VISUAL by sourcing profile.sh inside a subshell.
# @stdout The value of $VISUAL (possibly empty).
function read_visual() {
  (
    # shellcheck source=/dev/null
    source "${PROFILE_SH}" > /dev/null 2>&1
    printf '%s\n' "${VISUAL:-}"
  )
}

# @description Map a resolved program value to its candidate .desktop ids.
# Recognizes "flatpak run <APP_ID> [args...]" and a merged table covering
# editors, browsers, terminals, and file managers. Emits one candidate per
# line, most-preferred first; the caller picks the first that exists.
#
# The table is deliberately not data-driven: it maps a different fact than the
# preference chains do, and covers apps that are in no chain (code, codium,
# lapce). Candidate lists exist because AM/appman and the distro ship duplicate
# ids for the same binary (kitty.desktop vs kitty-AM.desktop).
# @arg $1 value The raw program value, e.g. "/usr/bin/kate --block".
# @stdout Zero or more "<id>.desktop" lines.
function desktop_for_bin() {
  local -r value="$1"
  local bin
  if [[ "${value}" == 'flatpak run '* ]]; then
    # "flatpak run <APP_ID> ..." — strip the prefix, take the first word.
    local rest="${value#flatpak run }"
    printf '%s.desktop\n' "${rest%% *}"
    return 0
  fi
  bin="${value%% *}" # strip args
  bin="${bin##*/}"   # strip path
  case "${bin}" in
    # editors
    'zed') printf 'dev.zed.Zed.desktop\n' ;;
    'kate') printf 'org.kde.kate.desktop\n' ;;
    'lite-xl') printf 'org.lite_xl.lite_xl.desktop\n' ;;
    'code') printf 'com.visualstudio.code.desktop\n' ;;
    'codium') printf 'com.vscodium.codium.desktop\n' ;;
    'lapce') printf 'dev.lapce.lapce.desktop\n' ;;
    'micro' | 'vim' | 'nano' | 'nvim' | 'hx') printf '%s.desktop\n' "${bin}" ;;
    # browsers
    'firefox') printf 'firefox.desktop\n' ;;
    'zen') printf 'app.zen_browser.zen.desktop\n' ;;
    'vivaldi') printf 'com.vivaldi.Vivaldi.desktop\n' ;;
    'chromium') printf 'org.chromium.Chromium.desktop\n' ;;
    'librewolf') printf 'io.gitlab.librewolf-community.desktop\n' ;;
    # terminals
    'ghostty') printf 'ghostty-AM.desktop\ncom.mitchellh.ghostty.desktop\nghostty.desktop\n' ;;
    'kitty') printf 'kitty-AM.desktop\nkitty.desktop\n' ;;
    'alacritty') printf 'alacritty-AM.desktop\nAlacritty.desktop\n' ;;
    'wezterm') printf 'wezterm-AM.desktop\norg.wezfurlong.wezterm.desktop\n' ;;
    'konsole') printf 'org.kde.konsole.desktop\n' ;;
    # file managers
    'dolphin') printf 'org.kde.dolphin.desktop\n' ;;
    'nautilus') printf 'org.gnome.Nautilus.desktop\n' ;;
    # ranger and other TUIs have no desktop entry by design.
    *) printf '' ;;
  esac
}

# @description Check whether a .desktop file exists in any XDG application dir.
# @arg $1 desktop Desktop file id (basename, e.g. dev.zed.Zed.desktop).
# @exitcode 0 if found, 1 if not.
function desktop_exists() {
  local -r desktop="$1"
  local dir
  for dir in "${XDG_APP_DIRS[@]}"; do
    [[ -f "${dir}/${desktop}" ]] && return 0
  done
  return 1
}

# @description Pick the first candidate .desktop id that exists on this host.
# @arg $1 value The raw program value.
# @stdout The winning "<id>.desktop", or nothing.
# @exitcode 0 if a candidate was found, 1 otherwise.
function resolve_desktop() {
  local -r value="$1"
  local candidate
  while IFS= read -r candidate; do
    [[ -n "${candidate}" ]] || continue
    if desktop_exists "${candidate}"; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(desktop_for_bin "${value}")
  return 1
}

# @description Assert that a command's stdout equals an expected string.
# @arg $1 desc Human-readable case description.
# @arg $2 expected Expected stdout (may be multi-line).
# @arg $@ rest Command and arguments to run.
function assert_stdout() {
  local -r desc="$1"
  local -r expected="$2"
  shift 2
  local actual
  actual="$("$@" 2> /dev/null || true)"
  if [[ "${actual}" == "${expected}" ]]; then
    printf 'ok   %s\n' "${desc}"
    return 0
  fi
  printf 'FAIL %s\n  expected: %q\n  actual:   %q\n' "${desc}" "${expected}" "${actual}"
  return 1
}

# @description Run the built-in test suite. No system state is touched.
# @exitcode 0 if every case passes, 1 otherwise.
function self_test() {
  local failures=0

  assert_stdout 'flatpak run form' \
    'dev.zed.Zed.desktop' \
    desktop_for_bin 'flatpak run dev.zed.Zed --wait' || failures=$((failures + 1))
  assert_stdout 'flatpak run without args' \
    'app.zen_browser.zen.desktop' \
    desktop_for_bin 'flatpak run app.zen_browser.zen' || failures=$((failures + 1))
  assert_stdout 'native bin, single candidate' \
    'firefox.desktop' \
    desktop_for_bin 'firefox' || failures=$((failures + 1))
  assert_stdout 'path-qualified bin' \
    'firefox.desktop' \
    desktop_for_bin '/usr/bin/firefox' || failures=$((failures + 1))
  assert_stdout 'bin with arguments' \
    'org.kde.kate.desktop' \
    desktop_for_bin 'kate --block' || failures=$((failures + 1))
  assert_stdout 'path-qualified bin with arguments' \
    'org.kde.kate.desktop' \
    desktop_for_bin '/usr/bin/kate --block' || failures=$((failures + 1))
  assert_stdout 'multi-candidate: ghostty' \
    'ghostty-AM.desktop
com.mitchellh.ghostty.desktop
ghostty.desktop' \
    desktop_for_bin 'ghostty' || failures=$((failures + 1))
  assert_stdout 'multi-candidate: kitty' \
    'kitty-AM.desktop
kitty.desktop' \
    desktop_for_bin 'kitty' || failures=$((failures + 1))
  assert_stdout 'multi-candidate: alacritty preserves case' \
    'alacritty-AM.desktop
Alacritty.desktop' \
    desktop_for_bin 'alacritty' || failures=$((failures + 1))
  assert_stdout 'generic <bin>.desktop arm' \
    'micro.desktop' \
    desktop_for_bin 'micro' || failures=$((failures + 1))
  assert_stdout 'unknown bin yields nothing' \
    '' \
    desktop_for_bin 'definitely-not-an-app' || failures=$((failures + 1))
  assert_stdout 'TUI file manager yields nothing' \
    '' \
    desktop_for_bin 'ranger' || failures=$((failures + 1))

  # resolve_desktop picks the first candidate that exists.
  # shellcheck disable=SC2329 # invoked indirectly via resolve_desktop, not by name
  function desktop_exists() { [[ "$1" == 'kitty.desktop' ]]; }
  assert_stdout 'resolve_desktop skips absent candidate' \
    'kitty.desktop' \
    resolve_desktop 'kitty' || failures=$((failures + 1))
  # shellcheck disable=SC2329 # invoked indirectly via resolve_desktop, not by name
  function desktop_exists() { return 1; }
  assert_stdout 'resolve_desktop yields nothing when none exist' \
    '' \
    resolve_desktop 'kitty' || failures=$((failures + 1))
  unset -f desktop_exists

  if ((failures > 0)); then
    printf '\n%d case(s) failed\n' "${failures}"
    return 1
  fi
  printf '\nall cases passed\n'
  return 0
}

function main() {
  if [[ "${1:-}" == '--self-test' ]]; then
    self_test
    exit $?
  fi
  if [[ ! -r "${PROFILE_SH}" ]]; then
    log::warn "${PROFILE_SH} not readable; skipping default-editor setup"
    exit 0
  fi
  if ! command -v 'xdg-mime' > /dev/null 2>&1; then
    log::warn 'xdg-mime not installed; skipping default-editor setup'
    exit 0
  fi

  local visual
  visual="$(read_visual)"
  if [[ -z "${visual}" ]]; then
    log::warn 'VISUAL is unset after sourcing profile.sh; skipping'
    exit 0
  fi

  local desktop
  if ! desktop="$(resolve_desktop "${visual}")"; then
    log::warn "VISUAL='${visual}' has no usable .desktop on this host; skipping"
    exit 0
  fi

  xdg-mime default "${desktop}" "${MIMES[@]}"
  log::info "Set ${desktop} as default for ${#MIMES[@]} MIME types"
}

main "$@"
