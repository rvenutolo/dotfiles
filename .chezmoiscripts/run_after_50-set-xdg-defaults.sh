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
# text/html and application/xhtml+xml belong to the browser role below.
readonly MIMES=(
  'application/javascript'
  'application/json'
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
  'text/json'
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

# Handlers owned by the browser role. Excludes x-scheme-handler/mailto, which
# is left to whatever the user has set.
readonly BROWSER_HANDLERS=(
  'application/xhtml+xml'
  'text/html'
  'x-scheme-handler/http'
  'x-scheme-handler/https'
)

# "Open terminal here" — Dolphin's F4, GNOME Files, xdg-terminal-exec.
readonly TERMINAL_HANDLERS=('x-scheme-handler/terminal')

readonly FILE_MANAGER_HANDLERS=('inode/directory')

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

# @description Read one variable's value by sourcing profile.sh in a subshell.
# @arg $1 name The variable name, e.g. BROWSER.
# @stdout The variable's value (possibly empty).
function read_var() {
  local -r name="$1"
  (
    # shellcheck source=/dev/null
    source "${PROFILE_SH}" > /dev/null 2>&1
    printf '%s\n' "${!name:-}"
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
    'firefox') printf 'firefox.desktop\norg.mozilla.firefox.desktop\n' ;;
    'chromium') printf 'org.chromium.Chromium.desktop\nchromium.desktop\n' ;;
    'google-chrome') printf 'com.google.Chrome.desktop\ngoogle-chrome.desktop\n' ;;
    'zen') printf 'app.zen_browser.zen.desktop\n' ;;
    'librewolf') printf 'io.gitlab.librewolf-community.desktop\nlibrewolf.desktop\n' ;;
    'brave') printf 'com.brave.Browser.desktop\nbrave-browser.desktop\nbrave.desktop\n' ;;
    'vivaldi') printf 'com.vivaldi.Vivaldi.desktop\nvivaldi-stable.desktop\n' ;;
    'opera') printf 'com.opera.Opera.desktop\nopera.desktop\n' ;;
    # w3m and lynx are text-mode and have no desktop entry by design.
    # terminals
    'ghostty') printf 'ghostty-AM.desktop\ncom.mitchellh.ghostty.desktop\nghostty.desktop\n' ;;
    'kitty') printf 'kitty-AM.desktop\nkitty.desktop\n' ;;
    'wezterm') printf 'wezterm-AM.desktop\norg.wezfurlong.wezterm.desktop\n' ;;
    'alacritty') printf 'alacritty-AM.desktop\nAlacritty.desktop\n' ;;
    'konsole') printf 'org.kde.konsole.desktop\n' ;;
    'gnome-terminal') printf 'org.gnome.Terminal.desktop\ngnome-terminal.desktop\n' ;;
    'kgx') printf 'org.gnome.Console.desktop\nkgx.desktop\n' ;;
    'xterm') printf 'xterm.desktop\ndebian-xterm.desktop\n' ;;
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

# @description Set one program as the default handler for a list of MIME types
# or URI schemes. Every failure is non-fatal: log a WARN and return 0 without
# applying anything.
# @arg $1 role Human-readable role name, e.g. "browser".
# @arg $2 varname Source variable name, e.g. BROWSER.
# @arg $@ handlers One or more MIME types / x-scheme-handler/* entries.
# @stdout The applied "<id>.desktop" on success; nothing on any skip.
function apply_defaults() {
  local -r role="$1"
  local -r varname="$2"
  shift 2
  local -ra handlers=("$@")
  local value desktop
  value="$(read_var "${varname}")"
  if [[ -z "${value}" ]]; then
    log::warn "${role}: \$${varname} is unset after sourcing profile.sh; skipping"
    return 0
  fi
  if ! desktop="$(resolve_desktop "${value}")"; then
    log::warn "${role}: no usable .desktop for '${value}'; skipping"
    return 0
  fi
  if ! xdg-mime default "${desktop}" "${handlers[@]}"; then
    log::warn "${role}: xdg-mime rejected ${desktop}; skipping"
    return 0
  fi
  log::info "${role}: set ${desktop} for ${#handlers[@]} handler(s)"
  printf '%s\n' "${desktop}"
}

# @description Report .desktop ids referenced by mimeapps.list that do not
# exist on this host. Report-only by design: the script runs on every apply,
# so pruning would fight any handler set in a GUI between applies, and cannot
# tell rot from an app mid-reinstall. Never modifies the file.
# @arg $1 file Optional path; defaults to ${HOME}/.config/mimeapps.list.
# @exitcode 0 always.
function scan_stale_handlers() {
  local -r file="${1:-${HOME}/.config/mimeapps.list}"
  if [[ ! -r "${file}" ]]; then
    return 0
  fi
  local id
  local stale=0
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    if ! desktop_exists "${id}"; then
      log::warn "stale handler in ${file}: ${id} (no .desktop found)"
      stale=$((stale + 1))
    fi
  done < <(grep --only-matching --extended-regexp '[A-Za-z0-9._+-]+\.desktop' "${file}" \
    | sort --unique || true)
  if ((stale > 0)); then
    log::warn "${stale} stale handler(s); prune by hand — this script never edits ${file}"
  fi
  return 0
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
  assert_stdout 'native bin, flatpak-second candidates' \
    'firefox.desktop
org.mozilla.firefox.desktop' \
    desktop_for_bin 'firefox' || failures=$((failures + 1))
  assert_stdout 'path-qualified bin' \
    'firefox.desktop
org.mozilla.firefox.desktop' \
    desktop_for_bin '/usr/bin/firefox' || failures=$((failures + 1))
  assert_stdout 'single candidate arm' \
    'app.zen_browser.zen.desktop' \
    desktop_for_bin 'zen' || failures=$((failures + 1))
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
  assert_stdout 'browser: google-chrome' \
    'com.google.Chrome.desktop
google-chrome.desktop' \
    desktop_for_bin 'google-chrome' || failures=$((failures + 1))
  assert_stdout 'browser: brave three candidates' \
    'com.brave.Browser.desktop
brave-browser.desktop
brave.desktop' \
    desktop_for_bin 'brave' || failures=$((failures + 1))
  assert_stdout 'browser: opera' \
    'com.opera.Opera.desktop
opera.desktop' \
    desktop_for_bin 'opera' || failures=$((failures + 1))
  assert_stdout 'browser: vivaldi' \
    'com.vivaldi.Vivaldi.desktop
vivaldi-stable.desktop' \
    desktop_for_bin 'vivaldi' || failures=$((failures + 1))
  assert_stdout 'browser: librewolf' \
    'io.gitlab.librewolf-community.desktop
librewolf.desktop' \
    desktop_for_bin 'librewolf' || failures=$((failures + 1))
  assert_stdout 'browser: chromium' \
    'org.chromium.Chromium.desktop
chromium.desktop' \
    desktop_for_bin 'chromium' || failures=$((failures + 1))
  assert_stdout 'text browser w3m yields nothing' \
    '' \
    desktop_for_bin 'w3m' || failures=$((failures + 1))
  assert_stdout 'text browser lynx yields nothing' \
    '' \
    desktop_for_bin 'lynx' || failures=$((failures + 1))
  assert_stdout 'terminal: wezterm' \
    'wezterm-AM.desktop
org.wezfurlong.wezterm.desktop' \
    desktop_for_bin 'wezterm' || failures=$((failures + 1))
  assert_stdout 'terminal: konsole' \
    'org.kde.konsole.desktop' \
    desktop_for_bin 'konsole' || failures=$((failures + 1))
  assert_stdout 'terminal: gnome-terminal' \
    'org.gnome.Terminal.desktop
gnome-terminal.desktop' \
    desktop_for_bin 'gnome-terminal' || failures=$((failures + 1))
  assert_stdout 'terminal: kgx (GNOME Console)' \
    'org.gnome.Console.desktop
kgx.desktop' \
    desktop_for_bin 'kgx' || failures=$((failures + 1))
  assert_stdout 'terminal: xterm last resort' \
    'xterm.desktop
debian-xterm.desktop' \
    desktop_for_bin 'xterm' || failures=$((failures + 1))
  assert_stdout 'file manager: dolphin' \
    'org.kde.dolphin.desktop' \
    desktop_for_bin 'dolphin' || failures=$((failures + 1))
  assert_stdout 'file manager: nautilus' \
    'org.gnome.Nautilus.desktop' \
    desktop_for_bin 'nautilus' || failures=$((failures + 1))

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
  # This removes the REAL desktop_exists, not just the stub — bash has no
  # "restore previous definition". Harmless here because every later case
  # re-stubs it, but a case appended after this point that calls
  # resolve_desktop/scan_stale_handlers without re-stubbing first will hit
  # "desktop_exists: command not found" rather than the real function.
  unset -f desktop_exists

  # apply_defaults short-circuits. xdg-mime is stubbed so nothing is applied.
  # The stub MUST stay silent: assert_stdout captures stdout, and apply_defaults
  # returns the applied desktop id on stdout, so any stub output corrupts it.
  # shellcheck disable=SC2329 # invoked indirectly via apply_defaults, not by name
  function xdg-mime() { return 0; }
  # shellcheck disable=SC2329 # invoked indirectly via apply_defaults, not by name
  function read_var() { printf '%s\n' "${STUB_VAR_VALUE:-}"; }
  # shellcheck disable=SC2329 # invoked indirectly via apply_defaults, not by name
  function desktop_exists() { [[ "$1" == 'firefox.desktop' ]]; }

  STUB_VAR_VALUE=''
  assert_stdout 'apply_defaults skips an unset variable' \
    '' \
    apply_defaults 'browser' 'BROWSER' 'text/html' || failures=$((failures + 1))

  STUB_VAR_VALUE='definitely-not-an-app'
  assert_stdout 'apply_defaults skips an unmapped bin' \
    '' \
    apply_defaults 'browser' 'BROWSER' 'text/html' || failures=$((failures + 1))

  STUB_VAR_VALUE='chromium'
  assert_stdout 'apply_defaults skips a mapped bin with no desktop file' \
    '' \
    apply_defaults 'browser' 'BROWSER' 'text/html' || failures=$((failures + 1))

  STUB_VAR_VALUE='/usr/bin/firefox'
  assert_stdout 'apply_defaults emits the applied desktop id' \
    'firefox.desktop' \
    apply_defaults 'browser' 'BROWSER' 'text/html' || failures=$((failures + 1))

  unset -f xdg-mime read_var desktop_exists
  unset STUB_VAR_VALUE

  # scan_stale_handlers is report-only: it must never modify the file.
  local fixture
  fixture="$(mktemp)"
  cat > "${fixture}" << 'FIXTURE'
[Default Applications]
text/html=alive.desktop
inode/directory=dead.desktop;
x-scheme-handler/http=alive.desktop;alsodead.desktop;
not a valid line at all
FIXTURE
  local -r fixture_before="$(cat "${fixture}")"
  # shellcheck disable=SC2329 # invoked indirectly via scan_stale_handlers, not by name
  function desktop_exists() { [[ "$1" == 'alive.desktop' ]]; }
  local stale_output
  stale_output="$(scan_stale_handlers "${fixture}" 2>&1 > /dev/null || true)"
  if [[ "${stale_output}" == *'dead.desktop'* && "${stale_output}" == *'alsodead.desktop'* &&
    "${stale_output}" != *'alive.desktop'* ]]; then
    printf 'ok   scan_stale_handlers reports only dead handlers\n'
  else
    printf 'FAIL scan_stale_handlers reports only dead handlers\n  got: %q\n' "${stale_output}"
    failures=$((failures + 1))
  fi
  if [[ "$(cat "${fixture}")" == "${fixture_before}" ]]; then
    printf 'ok   scan_stale_handlers does not modify the file\n'
  else
    printf 'FAIL scan_stale_handlers modified the file\n'
    failures=$((failures + 1))
  fi
  : > "${fixture}"
  if scan_stale_handlers "${fixture}" 2> /dev/null; then
    printf 'ok   scan_stale_handlers tolerates an empty file\n'
  else
    printf 'FAIL scan_stale_handlers failed on an empty file\n'
    failures=$((failures + 1))
  fi
  if scan_stale_handlers "${fixture}.does-not-exist" 2> /dev/null; then
    printf 'ok   scan_stale_handlers tolerates a missing file\n'
  else
    printf 'FAIL scan_stale_handlers failed on a missing file\n'
    failures=$((failures + 1))
  fi
  rm --force "${fixture}"
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
    log::warn "${PROFILE_SH} not readable; skipping XDG defaults setup"
    exit 0
  fi
  if ! command -v 'xdg-mime' > /dev/null 2>&1; then
    log::warn 'xdg-mime not installed; skipping XDG defaults setup'
    exit 0
  fi

  local browser_desktop
  browser_desktop="$(apply_defaults 'browser' 'BROWSER' "${BROWSER_HANDLERS[@]}")"
  if [[ -n "${browser_desktop}" ]] && command -v 'xdg-settings' > /dev/null 2>&1; then
    # Some applications consult xdg-settings rather than mimeapps.list.
    if xdg-settings set default-web-browser "${browser_desktop}" 2> /dev/null; then
      log::info "browser: set ${browser_desktop} via xdg-settings"
    else
      log::warn "browser: xdg-settings rejected ${browser_desktop}; mime defaults still applied"
    fi
  fi

  apply_defaults 'terminal' 'TERMINAL' "${TERMINAL_HANDLERS[@]}" > /dev/null
  apply_defaults 'file manager' 'FILE_MANAGER' "${FILE_MANAGER_HANDLERS[@]}" > /dev/null
  apply_defaults 'editor' 'VISUAL' "${MIMES[@]}" > /dev/null

  scan_stale_handlers
}

main "$@"
