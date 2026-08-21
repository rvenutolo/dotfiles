#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# The scanner emits BYTE offsets, and this script slices the raw command back out
# with ${command:offset:length}. Bash string operations are locale-aware, so under
# a UTF-8 locale a single multibyte character earlier in the command shifts every
# later slice and silently voids the bracket mitigation. Force the C locale so the
# two index bases agree.
export LC_ALL=C

if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3))); then
  printf '{}\n'
  exit 0
fi

readonly -a SELF_TEST_CASES=(
  $'ls -la\tallow'
  $'echo hello\tallow'
  $'grep --recursive "until ! pgrep --full x" .\tallow'
  $'echo "pgrep --full x"\tallow'
  $'echo "while until pgrep --full x"\tallow'
  $'pgrep java\tallow'
  $'pgrep -a java\tallow'
  $'until ! pgrep --full "unittest discover" > /dev/null 2>&1; do sleep 5; done\tdeny:loop'
  $'while pgrep -f build >/dev/null; do sleep 2; done\tdeny:loop'
  $'while true; do pgrep --full x >/dev/null || break; sleep 5; done\tdeny:loop'
  $'until ! pgrep --ignore-ancestors --full x; do sleep 5; done\tallow'
  $'until ! pgrep -Af x; do sleep 5; done\tallow'
  $'until ! pgrep --full "[u]nittest discover"; do sleep 5; done\tallow'
  $'echo "unittest discover"; until ! pgrep --full "[u]nittest discover"; do sleep 5; done\tdeny:loop'
  $'pkill --full "unittest discover"\tdeny:kill'
  $'pgrep --full java | xargs kill\tdeny:kill'
  $'pkill --ignore-ancestors --full java\tallow'
  $'while read -r line; do :; done < f; pgrep -af java\tallow'
  $'for f in *; do :; done; pgrep --full x && echo yes\twarn'
  $'pgrep --full x >/dev/null && echo running\twarn'
  $'pgrep --full x | wc -l\twarn'
  $'pgrep -cf java\twarn'
  $'while [ -n "$p" ]; do p=$(pgrep --full x); sleep 5; done\twarn'
  $'pgrep -af java\tallow'
  $'pgrep --list-full --full java\tallow'
  # NEW rows covering the review findings
  # A valid silent-allow case, but a stray `&` alone does not exercise the
  # redirection-target guard in result_is_consumed (amp only reaches 1).
  $'pgrep -af java > /tmp/x 2>&1\tallow'
  $'until [ -z "$(pgrep --full x)" ]; do sleep 5; done\tdeny:loop'
  $'echo hi\nuntil ! pgrep --full x\ndo sleep 5\ndone\tdeny:loop'
  $'pgrep --full x &\tallow'
  # Backtick command substitution, both quoted and unquoted (Task 2 regression).
  # The quoted row pins the context-stack special-casing; the unquoted row pins
  # the tokenizer's operator set -- removing the backtick from either breaks it.
  $'until [ -z "`pgrep --full x`" ]; do sleep 5; done\tdeny:loop'
  $'until [ -z `pgrep --full x` ]; do sleep 5; done\tdeny:loop'
  # Command substitution into kill: same session-killing effect as pkill --full.
  $'kill $(pgrep --full x)\tdeny:kill'
  $'kill -9 $(pgrep --full x)\tdeny:kill'
  $'sudo kill $(pgrep --full x)\tdeny:kill'
  # `kill` as an argument word is not a kill form; it must be in command position.
  $'echo kill $(pgrep --full x)\twarn'
  # A prefix chain before kill is still a kill form.
  $'true; kill $(pgrep --full x)\tdeny:kill'
  # A substitution feeding something harmless is still only a warn.
  $'echo $(pgrep --full x)\twarn'
  # Exercises the redirection-target guard: a real pipe followed by a redirect
  # into a file literally named `wc` must not read as "piped into wc".
  $'pgrep --full x | sort > wc\tallow'

  # F1 -- unquoted `#` comments. One apostrophe in prose inverts quote parity for
  # the rest of the command, and it fails in both directions: the first row
  # exposes a quoted string as if it were code, the second hides a real loop.
  $'# don\'t do it\necho \'while true; do pgrep --full x || break; sleep 5; done\'\tallow'
  $'# don\'t do this\nuntil ! pgrep --full y; do sleep 5; done\tdeny:loop'
  # The `#` of ${#arr[@]} follows `{`, not whitespace, so it opens no comment.
  # Without that precondition the rest of the line is masked and the loop escapes.
  $'n=${#arr[@]}; until ! pgrep --full x; do sleep 5; done\tdeny:loop'

  # F2 -- a command substitution that has already CLOSED is not a capture. The
  # first row is a bounded five-iteration loop that only prints; a prefix
  # substring test read the `$(seq ...)` as capturing the pgrep and denied it.
  $'for i in $(seq 1 5); do pgrep -af java; [ "$i" -gt 2 ] && break; done\tallow'
  $'echo $(date); pgrep --full java\tallow'

  # F3 -- the scanner emits byte offsets; a multibyte character earlier in the
  # command must not shift the slice that recovers the pattern operand.
  $'echo "→ checking"; until ! pgrep --full "[u]nittest discover"; do sleep 5; done\tallow'

  # F4 -- `kill` must head a pipeline segment (or follow an `xargs` that does).
  # Searching output for the word "kill" kills nothing.
  $'pgrep --full x | grep -i kill\tallow'
  $'pgrep --full java | xargs --no-run-if-empty kill -9\tdeny:kill'

  # F5 -- prefix commands and absolute paths must not defeat the guard.
  $'sudo pkill --full java\tdeny:kill'
  $'command pkill --full java\tdeny:kill'
  $'/usr/bin/pgrep --full x | xargs kill\tdeny:kill'
  $'until ! sudo pgrep --full x; do sleep 5; done\tdeny:loop'

  # F6 -- an enclosing `if`/`elif`, or a leading `!`, reads the exit status as a
  # boolean, which is exactly the reading the off-by-one corrupts.
  $'if pgrep --full "java -jar app" > /dev/null; then echo up; fi\twarn'
  $'! pgrep --full java\twarn'
  $'if ! pgrep -f java; then echo down; fi\twarn'
)

# @description Tokenize a command, masking quoted regions.
# @arg $1 command the command string
# @stdout offset and token pairs, separated by tab
function scan_command() {
  local -r command="$1"
  printf '%s' "${command}" | LC_ALL=C awk -f "${SCANNER}"
}

# @description Assert helper used by the scanner unit checks.
# @arg $1 label description
# @arg $2 expected expected value
# @arg $3 actual actual value
# @exitcode 0 match
# @exitcode 1 mismatch
function assert_equals() {
  local -r label="$1"
  local -r expected="$2"
  local -r actual="$3"
  if [[ "${expected}" != "${actual}" ]]; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "${label}" "${expected}" "${actual}" >&2
    return 1
  fi
}

# @description Unit checks for the scanner.
# @noargs
# @exitcode 0 all assertions held
function run_scanner_tests() {
  local failures=0

  assert_equals 'quoted mention yields no pgrep token' \
    '0' "$(scan_command 'grep -r "until ! pgrep --full x" .' | grep --count '\bpgrep$' || true)" \
    || failures=$((failures + 1))

  assert_equals 'bare pgrep is tokenized' \
    'pgrep' "$(scan_command 'pgrep --full x' | awk -F'\t' 'NR==1 {print $2}')" \
    || failures=$((failures + 1))

  # shellcheck disable=SC2016
  assert_equals 'command substitution inside double quotes is visible' \
    '14' "$(scan_command 'until [ -z "$(pgrep --full x)" ]; do sleep 5; done' \
      | awk -F'\t' '$2 == "pgrep" {print $1}')" \
    || failures=$((failures + 1))

  assert_equals 'newline survives as a literal token' \
    '<NL>' "$(scan_command "$(printf 'echo hi\nls')" | awk -F'\t' 'NR==3 {print $2}')" \
    || failures=$((failures + 1))

  assert_equals 'long full flag' 'yes' "$(flag_probe 'pgrep --full x' '--full' 'f')" \
    || failures=$((failures + 1))
  assert_equals 'short cluster -af is full' 'yes' "$(flag_probe 'pgrep -af x' '--full' 'f')" \
    || failures=$((failures + 1))
  assert_equals 'plain -a is not full' 'no' "$(flag_probe 'pgrep -a x' '--full' 'f')" \
    || failures=$((failures + 1))
  assert_equals 'long ignore-ancestors' 'yes' \
    "$(flag_probe 'pgrep --ignore-ancestors --full x' '--ignore-ancestors' 'A')" \
    || failures=$((failures + 1))
  assert_equals 'short -A' 'yes' "$(flag_probe 'pgrep -Af x' '--ignore-ancestors' 'A')" \
    || failures=$((failures + 1))
  assert_equals 'operand is last non-flag arg' 'unittest discover' \
    "$(pattern_probe 'pgrep --full "unittest discover"')" || failures=$((failures + 1))
  assert_equals 'operand skips a flag value' 'java' \
    "$(pattern_probe 'pgrep --full --delimiter , java')" || failures=$((failures + 1))
  assert_equals 'operand ignores a redirection target' 'x' \
    "$(pattern_probe 'pgrep --full x > /tmp/out')" || failures=$((failures + 1))

  assert_equals 'bracket alone holds' 'yes' \
    "$(bracket_probe 'pgrep --full "[u]nittest discover"')" || failures=$((failures + 1))
  assert_equals 'bracket voided by a bare copy' 'no' \
    "$(bracket_probe 'echo "unittest discover"; pgrep --full "[u]nittest discover"')" \
    || failures=$((failures + 1))
  assert_equals 'no bracket, no mitigation' 'no' \
    "$(bracket_probe 'pgrep --full "unittest discover"')" || failures=$((failures + 1))
  assert_equals 'bracket later in the pattern holds' 'yes' \
    "$(bracket_probe 'pgrep --full "probe[.]py"')" || failures=$((failures + 1))

  assert_equals 'multi-char class is not the idiom' 'no' \
    "$(bracket_probe 'pgrep --full "[abc]needle[d]"')" || failures=$((failures + 1))
  assert_equals 'single then multi-char class' 'no' \
    "$(bracket_probe 'pgrep --full "[d]needle[abc]"')" || failures=$((failures + 1))

  assert_equals 'stray class opener is unreconstructable' 'no' \
    "$(bracket_probe 'pgrep --full "abc[def[g]hij"')" || failures=$((failures + 1))

  assert_equals 'condition span' 'cond' \
    "$(context_probe 'until ! pgrep --full x; do sleep 5; done')" || failures=$((failures + 1))
  assert_equals 'body span' 'body' \
    "$(context_probe 'while true; do pgrep --full x || break; sleep 5; done')" \
    || failures=$((failures + 1))
  assert_equals 'outside every loop' 'none' \
    "$(context_probe 'while read -r line; do :; done < f; pgrep -af java')" \
    || failures=$((failures + 1))
  # shellcheck disable=SC2016
  assert_equals 'for head is not a condition' 'none' \
    "$(context_probe 'for f in $(pgrep --full x); do :; done')" || failures=$((failures + 1))
  assert_equals 'nested loop attributes to inner body' 'body' \
    "$(context_probe 'while true; do for f in *; do pgrep --full x || break; done; done')" \
    || failures=$((failures + 1))
  assert_equals 'done as an argument does not close a span' 'body' \
    "$(context_probe 'while true; do echo done; pgrep --full x || break; done')" \
    || failures=$((failures + 1))
  assert_equals 'body terminator found' 'yes' \
    "$(terminator_probe 'while true; do pgrep --full x || break; done')" || failures=$((failures + 1))
  assert_equals 'no terminator in body' 'no' \
    "$(terminator_probe 'while true; do pgrep --full x; sleep 5; done')" || failures=$((failures + 1))
  assert_equals 'terminator in an outer body only' 'no' \
    "$(terminator_probe 'while true; do for f in *; do pgrep --full x; done; break; done')" \
    || failures=$((failures + 1))

  # A guard that dies quietly is worse than no guard, so both missing-dependency
  # branches are exercised against a real end-to-end run of a copy of this script.
  # The stub PATH holds only what the script needs before the awk check.
  local probe_dir stub_dir binary
  probe_dir="$(mktemp --directory)"
  stub_dir="${probe_dir}/bin"
  mkdir --parents "${stub_dir}"
  for binary in bash jq dirname cat; do
    ln --symbolic "$(command -v "${binary}" || printf '/nonexistent')" "${stub_dir}/${binary}" \
      || true
  done
  cp "${SCRIPT_PATH}" "${probe_dir}/hook.sh"
  cp "${SCANNER}" "${probe_dir}/pgrep-scan.awk"
  assert_equals 'missing awk announces the guard inactive' 'inactive' \
    "$(inactive_probe "${probe_dir}/hook.sh" "${stub_dir}")" || failures=$((failures + 1))
  rm --force "${probe_dir}/pgrep-scan.awk"
  assert_equals 'missing scanner announces the guard inactive' 'inactive' \
    "$(inactive_probe "${probe_dir}/hook.sh" "${PATH}")" || failures=$((failures + 1))
  rm --recursive --force "${probe_dir}"

  if ((failures > 0)); then
    return 1
  fi
}

# @description Self-test helper: run a copy of this hook end to end and report whether it announced
#              that the guard is inactive, rather than dying into the ERR trap's silent allow. The
#              probe command must contain `pgrep`, or classify_command short-circuits before the
#              scanner is ever reached and a dead scanner looks healthy. The child runs under
#              `env --ignore-environment`: a plain PATH prefix assignment is not enough, because a
#              BASH_ENV inherited from the caller re-sources the user's profile, which rebuilds PATH
#              and quietly restores the very binary the probe is trying to remove.
# @arg $1 script path to the hook copy to run
# @arg $2 path the PATH that copy should see
# @stdout inactive or active
function inactive_probe() {
  local -r script="$1"
  local -r path="$2"
  local output
  output="$(printf '{"tool_name":"Bash","tool_input":{"command":"pkill --full java"}}' \
    | env --ignore-environment "PATH=${path}" bash "${script}" 2> /dev/null || true)"
  if [[ "${output}" == *INACTIVE* ]]; then printf 'inactive\n'; else printf 'active\n'; fi
}

# @description Self-test helper: does the first invocation carry a flag class?
# @arg $1 command the command string
# @arg $2 long the long option
# @arg $3 short the short cluster letter
# @stdout yes or no
function flag_probe() {
  local -r command="$1"
  local -r long="$2"
  local -r short="$3"
  local tokens
  tokens="$(scan_command "${command}")"
  local idx
  idx="$(find_invocations "${tokens}" | head --lines=1 | cut --fields=1)"
  local args
  args="$(invocation_args "${tokens}" "${idx}")"
  if has_flag "${args}" "${long}" "${short}"; then printf 'yes\n'; else printf 'no\n'; fi
}

# @description Self-test helper: the pattern operand of the first invocation.
# @arg $1 command the command string
# @stdout the operand, or empty
function pattern_probe() {
  local -r command="$1"
  local tokens
  tokens="$(scan_command "${command}")"
  local idx
  idx="$(find_invocations "${tokens}" | head --lines=1 | cut --fields=1)"
  local args
  args="$(invocation_args "${tokens}" "${idx}")"
  pattern_operand "${command}" "${args}"
}

# @description Self-test helper: does the bracket mitigation hold?
# @arg $1 command the command string
# @stdout yes or no
function bracket_probe() {
  local -r command="$1"
  local tokens
  tokens="$(scan_command "${command}")"
  local idx
  idx="$(find_invocations "${tokens}" | head --lines=1 | cut --fields=1)"
  local args
  args="$(invocation_args "${tokens}" "${idx}")"
  local operand
  operand="$(pattern_operand "${command}" "${args}")"
  if bracket_mitigation_holds "${command}" "${operand}"; then printf 'yes\n'; else printf 'no\n'; fi
}

# @description Self-test helper: loop context of the first invocation.
# @arg $1 command the command string
# @stdout none, cond, or body
function context_probe() {
  local -r command="$1"
  local tokens
  tokens="$(scan_command "${command}")"
  local idx
  idx="$(find_invocations "${tokens}" | head --lines=1 | cut --fields=1)"
  loop_context "${tokens}" "${idx}"
}

# @description Self-test helper: does the loop body enclosing the first invocation
#              contain a break, exit or return?
# @arg $1 command the command string
# @stdout yes or no
function terminator_probe() {
  local -r command="$1"
  local tokens
  tokens="$(scan_command "${command}")"
  local idx
  idx="$(find_invocations "${tokens}" | head --lines=1 | cut --fields=1)"
  if body_has_terminator "${tokens}" "${idx}"; then printf 'yes\n'; else printf 'no\n'; fi
}

# @description Run the built-in case table.
# @noargs
# @exitcode 0 all cases matched
# @exitcode 1 at least one case mismatched
function run_self_test() {
  local failures=0
  if ! run_scanner_tests; then
    failures=$((failures + 1))
  fi
  local case_line expected actual command
  for case_line in "${SELF_TEST_CASES[@]}"; do
    command="${case_line%%$'\t'*}"
    expected="${case_line##*$'\t'}"
    actual="$(classify_command "${command}")"
    if [[ "${actual}" != "${expected}" ]]; then
      printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' \
        "${command//$'\n'/\\n}" "${expected}" "${actual}" >&2
      failures=$((failures + 1))
    fi
  done
  if ((failures > 0)); then
    printf '%d self-test failure(s)\n' "${failures}" >&2
    return 1
  fi
  printf 'all %d self-test cases passed\n' "${#SELF_TEST_CASES[@]}"
}

# Any unexpected failure must still allow the command. A hook that dies non-zero
# surfaces an error on every Bash call; exit 2 would block the tool outright.
trap 'emit_allow; exit 0' ERR

# Resolve the scanner relative to this script rather than via CLAUDE_CONFIG_DIR,
# which is not guaranteed to be exported into the hook's environment.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly SCANNER="${SCRIPT_DIR}/pgrep-scan.awk"
readonly SCRIPT_PATH="${SCRIPT_DIR}/${BASH_SOURCE[0]##*/}"

readonly HOOK_NAME='block-pgrep-self-match'

# Keywords after which the next word is in command position.
readonly -a COMMAND_POSITION_KEYWORDS=(
  'do' 'then' 'else' 'elif' 'while' 'until' 'if' 'for' 'select' '!' 'time'
)

# Words that run another command and so preserve command position for the word
# after them. `sudo pkill --full java` is the single most likely session-killing
# form, so the guard must see through the prefix.
readonly -a PREFIX_COMMANDS=('sudo' 'doas' 'env' 'nohup' 'command' 'time')

# @description True when a token is a command prefix that keeps the following word in command
#              position.
# @arg $1 token the token to test
# @exitcode 0 the token is a prefix command
# @exitcode 1 it is not
function is_prefix_command() {
  local -r token="$1"
  local prefix
  for prefix in "${PREFIX_COMMANDS[@]}"; do
    [[ "${token}" == "${prefix}" ]] && return 0
  done
  return 1
}

# @description True when a token is a shell keyword after which the next word is again in
#              command position.
# @arg $1 token the token to test
# @exitcode 0 the token is such a keyword
# @exitcode 1 it is not
function is_keyword() {
  local -r token="$1"
  local keyword
  for keyword in "${COMMAND_POSITION_KEYWORDS[@]}"; do
    [[ "${token}" == "${keyword}" ]] && return 0
  done
  return 1
}

# @description True when a token is a shell operator that ends a simple command. The backtick
#              counts: the scanner emits it as a standalone token and it restores command position.
# @arg $1 token the token to test
# @exitcode 0 the token is an operator
# @exitcode 1 it is not
function is_operator() {
  case "$1" in
    ';' | '&' | '|' | '(' | ')' | '{' | '}' | '<NL>' | '`') return 0 ;;
    *) return 1 ;;
  esac
}

# @description Locate pgrep/pkill invocations that sit in command position. A quoted mention such as
#              `grep -r "until ! pgrep --full"` yields nothing, because the scanner masked it. A
#              leading run of prefix words (`sudo`, `command`, ...) keeps command position, and the
#              token is matched on its basename so `/usr/bin/pgrep` counts.
# @arg $1 tokens newline-separated "<offset>\t<token>" records from scan_command
# @stdout lines of "<index>\t<offset>\t<basename>"
function find_invocations() {
  local at_cmd=1 idx=0 offset token word next_at_cmd
  local -r tokens="$1"
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    word="${token##*/}"
    if ((at_cmd == 1)) && [[ "${word}" == 'pgrep' || "${word}" == 'pkill' ]]; then
      printf '%s\t%s\t%s\n' "${idx}" "${offset}" "${word}"
    fi
    if is_operator "${token}" || is_keyword "${token}"; then
      next_at_cmd=1
    elif ((at_cmd == 1)) && is_prefix_command "${word}"; then
      # Only a prefix that is itself in command position chains: in `git command x`
      # the word `command` is an argument, not a prefix.
      next_at_cmd=1
    else
      next_at_cmd=0
    fi
    at_cmd="${next_at_cmd}"
    idx=$((idx + 1))
  done <<< "${tokens}"
}

# @description Collect one invocation's argument tokens: everything after the command name, up to
#              the operator that ends the simple command.
# @arg $1 tokens the token stream from scan_command
# @arg $2 target index of the pgrep/pkill token itself
# @stdout lines of "<offset>\t<token>"
function invocation_args() {
  local -r tokens="$1"
  local -r target="$2"
  local idx=0 offset token
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((idx > target)); then
      is_operator "${token}" && break
      printf '%s\t%s\n' "${offset}" "${token}"
    fi
    idx=$((idx + 1))
  done <<< "${tokens}"
}

# @description True when an invocation's arguments carry a flag, as either the long option or a
#              short cluster containing the letter. A bare -- ends option parsing.
# @arg $1 args newline-separated "<offset>\t<token>" lines
# @arg $2 long the long option, for example --full
# @arg $3 short the short cluster letter, for example f
# @exitcode 0 the flag is present
# @exitcode 1 it is absent
function has_flag() {
  local -r args="$1" long="$2" short="$3"
  local offset token
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    [[ "${token}" == '--' ]] && return 1
    [[ "${token}" == "${long}" ]] && return 0
    if [[ "${token}" == -[a-zA-Z]* && "${token}" != --* && "${token}" == *"${short}"* ]]; then return 0; fi
  done <<< "${args}"
  return 1
}

# Long options that take a separate value, so that value is not the operand.
readonly -a PGREP_VALUE_OPTIONS=(
  '--delimiter' '--parent' '--pgroup' '--session' '--terminal' '--uid' '--euid'
  '--group' '--ns' '--nslist' '--signal' '--older'
)

# @description Extract the search pattern: the last argument that is neither a flag, a flag's value,
#              nor a redirection. Sliced out of the raw command by offset so the original quoting
#              survives, then one surrounding quote pair is stripped.
# @arg $1 command the raw command string
# @arg $2 args newline-separated "<offset>\t<token>" lines
# @stdout the operand with surrounding quotes removed, or empty
function pattern_operand() {
  local -r command="$1" args="$2"
  local operand_offset='' operand_length=0 skip=0 offset token value_option
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((skip == 1)); then
      skip=0
      continue
    fi
    case "${token}" in
      --*)
        for value_option in "${PGREP_VALUE_OPTIONS[@]}"; do
          [[ "${token}" == "${value_option}" ]] && skip=1 && break
        done
        ;;
      -*) : ;;
      *[\<\>]*)
        [[ "${token}" == '>' || "${token}" == '<' || "${token}" == '>>' ]] && skip=1
        ;;
      *)
        operand_offset="${offset}"
        operand_length="${#token}"
        ;;
    esac
  done <<< "${args}"
  [[ -z "${operand_offset}" ]] && return 0
  local raw="${command:operand_offset:operand_length}"
  if [[ "${raw}" == \"*\" || "${raw}" == \'*\' ]]; then raw="${raw:1:${#raw}-2}"; fi
  printf '%s' "${raw}"
}

# @description Decide whether a bracket-class pattern actually defeats self-match. It does only when
#              the de-bracketed literal appears nowhere else in the command line: a single-character
#              class hides the needle from its own regex, but an unbracketed copy elsewhere in the
#              same `bash -c` argument puts it straight back.
# @arg $1 command the raw command string
# @arg $2 operand the pattern operand, quotes already stripped
# @exitcode 0 the mitigation holds
# @exitcode 1 no bracket class, or the bare literal occurs elsewhere
function bracket_mitigation_holds() {
  local -r command="$1" operand="$2"
  [[ -z "${operand}" ]] && return 1
  [[ "${operand}" != *\[?\]* ]] && return 1
  local bare="${operand}"
  local prefix rest
  while [[ "${bare}" == *\[?\]* ]]; do
    prefix="${bare%%\[?\]*}"
    rest="${bare#"${prefix}"}"
    bare="${prefix}${rest:1:1}${rest:3}"
  done
  # A surviving `[` means an unresolved class opener whose literal text cannot be
  # reconstructed. A surviving `]` is just a literal character and is fine.
  [[ "${bare}" == *\[* ]] && return 1
  [[ -z "${bare}" ]] && return 1
  [[ "${command}" == *"${bare}"* ]] && return 1
  return 0
}

# @description Determine whether a token index sits inside a while/until condition, inside any loop
#              body, or outside every loop. A for/select head reports "none": it is evaluated once,
#              so a self-matching pgrep there pins no termination test.
# @arg $1 tokens the token stream from scan_command
# @arg $2 target index of the invocation token
# @stdout none, cond, or body
function loop_context() {
  local -r tokens="$1" target="$2"
  local -a stack=()
  local idx=0 at_cmd=1 offset token
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((idx == target)); then
      if ((${#stack[@]} == 0)); then
        printf 'none\n'
        return 0
      fi
      case "${stack[${#stack[@]} - 1]}" in
        cond) printf 'cond\n' ;;
        body) printf 'body\n' ;;
        *) printf 'none\n' ;;
      esac
      return 0
    fi
    if ((at_cmd == 1)); then
      case "${token}" in
        'while' | 'until') stack+=('cond') ;;
        'for' | 'select') stack+=('head') ;;
        'do')
          ((${#stack[@]} > 0)) && unset 'stack[${#stack[@]}-1]'
          stack+=('body')
          ;;
        'done') ((${#stack[@]} > 0)) && unset 'stack[${#stack[@]}-1]' ;;
      esac
    fi
    if is_operator "${token}" || is_keyword "${token}"; then at_cmd=1; else at_cmd=0; fi
    idx=$((idx + 1))
  done <<< "${tokens}"
  printf 'none\n'
}

# @description True when the loop body enclosing an invocation contains a break, exit or return in
#              command position, which makes a body-position pgrep the effective termination test.
# @arg $1 tokens the token stream from scan_command
# @arg $2 target index of the invocation token
# @exitcode 0 a terminator is present in the enclosing body
# @exitcode 1 no terminator
function body_has_terminator() {
  local -r tokens="$1" target="$2"
  local depth=0 seen=0 at_cmd=1 idx=0 offset token
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    ((idx == target)) && seen=1
    if ((at_cmd == 1)); then
      case "${token}" in
        'do') depth=$((depth + 1)) ;;
        'done')
          ((seen == 1 && depth > 0)) && return 1
          ((depth > 0)) && depth=$((depth - 1))
          ;;
        'break' | 'exit' | 'return') ((depth > 0)) && return 0 ;;
      esac
    fi
    if is_operator "${token}" || is_keyword "${token}"; then at_cmd=1; else at_cmd=0; fi
    idx=$((idx + 1))
  done <<< "${tokens}"
  return 1
}

# @description Emit an allow decision.
# @noargs
function emit_allow() {
  printf '{}\n'
}

# @description Allow the command but attach model-visible context.
#              additionalContext is the only PreToolUse field verified to reach
#              the model on an allowed call; systemMessage renders to the user
#              only, and permissionDecisionReason is fed back under deny alone.
# @arg $1 text the message the model should read
function emit_warn() {
  local -r text="$1"
  jq --null-input --arg msg "${text}" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      additionalContext: $msg
    }
  }'
}

# @description Emit a deny decision.
# @arg $1 text the reason shown to the model
function emit_deny() {
  local -r text="$1"
  jq --null-input --arg msg "${text}" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $msg
    }
  }'
}

# @description True when an invocation's output is piped into a kill, or when the invocation is
#              itself substituted into a kill's argument list (`kill $(pgrep ...)` and the backtick
#              equivalent). The forward pipeline scan requires `kill` to head a pipeline segment, or
#              to follow an `xargs` that heads one, with flags and prefix words allowed in between:
#              `pgrep --full x | grep -i kill` merely searches for the word and kills nothing.
# @arg $1 tokens the token stream from scan_command
# @arg $2 target index of the invocation token
# @exitcode 0 output feeds a kill
# @exitcode 1 it does not
function feeds_a_kill() {
  local -r tokens="$1" target="$2"
  local -a seq=()
  local idx=0 seen=0 segment='none' offset token word
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    seq+=("${token}")
    if ((idx == target)); then
      seen=1
      idx=$((idx + 1))
      continue
    fi
    if ((seen == 1)); then
      word="${token##*/}"
      case "${word}" in
        '|') segment='head' ;;
        ';' | '<NL>') seen=2 ;;
        *)
          case "${segment}" in
            head)
              if [[ "${word}" == 'kill' ]]; then
                return 0
              elif [[ "${word}" == 'xargs' ]]; then
                segment='xargs'
              elif ! is_prefix_command "${word}"; then
                segment='other'
              fi
              ;;
            xargs)
              if [[ "${word}" == 'kill' ]]; then
                return 0
              elif [[ "${word}" != -* ]] && ! is_prefix_command "${word}"; then
                segment='other'
              fi
              ;;
          esac
          ;;
      esac
    fi
    idx=$((idx + 1))
  done <<< "${tokens}"

  # Backward form: `kill $(pgrep ...)`, `kill -9 $(pgrep ...)`, and the backtick
  # equivalent. Here `kill` precedes the invocation, so the forward scan cannot
  # see it. Skip the substitution punctuation and any flags on the way back, then
  # require the `kill` to be in command position -- otherwise `echo kill $(...)`,
  # where `kill` is merely an argument word, would be denied.
  local k=$((target - 1)) m
  while ((k >= 0)); do
    word="${seq[k]##*/}"
    case "${word}" in
      '$' | '(' | '`') ;;
      -*) ;;
      'kill')
        m=$((k - 1))
        while ((m >= 0)); do
          if is_prefix_command "${seq[m]##*/}"; then
            m=$((m - 1))
            continue
          fi
          if is_operator "${seq[m]}" || is_keyword "${seq[m]}"; then return 0; fi
          return 1
        done
        return 0
        ;;
      *) return 1 ;;
    esac
    k=$((k - 1))
  done
  return 1
}

# @description True when an invocation sits inside a command substitution, so its output is captured
#              rather than printed. Counted as a depth over the token stream: a substring test on the
#              raw command prefix cannot tell an enclosing `$(` from an unrelated one that has
#              already closed, which made `for i in $(seq 1 5); do pgrep -af java; ...; done` read as
#              a capture. `$` is not an operator token, so the opener is recognised as any token
#              ending in `$` immediately followed by `(`, which also covers `p=$(...)`.
# @arg $1 tokens the token stream from scan_command
# @arg $2 target index of the invocation token
# @exitcode 0 the invocation is inside a command substitution
# @exitcode 1 it is not
function invocation_is_captured() {
  local -r tokens="$1" target="$2"
  local -a stack=()
  local idx=0 dollar=0 offset token entry
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((idx == target)); then
      if ((${#stack[@]} == 0)); then
        return 1
      fi
      for entry in "${stack[@]}"; do
        [[ "${entry}" == 'capture' || "${entry}" == 'backtick' ]] && return 0
      done
      return 1
    fi
    case "${token}" in
      '(')
        if ((dollar == 1)); then stack+=('capture'); else stack+=('subshell'); fi
        ;;
      ')')
        if ((${#stack[@]} > 0)); then unset 'stack[${#stack[@]}-1]'; fi
        ;;
      '`')
        if ((${#stack[@]} > 0)) && [[ "${stack[${#stack[@]} - 1]}" == 'backtick' ]]; then
          unset 'stack[${#stack[@]}-1]'
        else
          stack+=('backtick')
        fi
        ;;
    esac
    if [[ "${token}" == *'$' ]]; then dollar=1; else dollar=0; fi
    idx=$((idx + 1))
  done <<< "${tokens}"
  return 1
}

# @description True when an invocation's result is read as a boolean, a count, or captured into a
#              variable, rather than merely displayed. Only then can the silent off-by-one produce a
#              wrong conclusion. Four shapes count: pgrep's own `--count` / `-c`; an enclosing `if`
#              or `elif`, or a leading `!`, which read the exit status as a boolean; a following
#              `&&`, `||`, `| wc` or `| xargs`; and sitting inside a command substitution. A
#              redirection target is not consumption: `2>&1` tokenizes as `2>`, `&`, `1`, and a lone
#              trailing `&` is backgrounding rather than a boolean operator.
# @arg $1 tokens the token stream from scan_command
# @arg $2 target index of the invocation token
# @arg $3 args the invocation's argument lines
# @exitcode 0 the result is consumed
# @exitcode 1 the result is only displayed
function result_is_consumed() {
  local -r tokens="$1" target="$2" args="$3"
  local offset token
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    [[ "${token}" == '--count' ]] && return 0
    if [[ "${token}" == -[a-zA-Z]* && "${token}" != --* && "${token}" == *c* ]]; then return 0; fi
  done <<< "${args}"

  # An enclosing `if` / `elif`, or a negation, reads the exit status as a boolean.
  # Walk back over prefix words so `if sudo pgrep --full x` still counts.
  local -a seq=()
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    seq+=("${token}")
  done <<< "${tokens}"
  local k=$((target - 1)) word
  while ((k >= 0)); do
    word="${seq[k]##*/}"
    case "${word}" in
      'if' | 'elif' | '!') return 0 ;;
      *) is_prefix_command "${word}" || break ;;
    esac
    k=$((k - 1))
  done

  local idx=0 seen=0 prev='' amp=0 pipe=0
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((idx == target)); then
      seen=1
      idx=$((idx + 1))
      prev="${token}"
      continue
    fi
    if ((seen == 1)); then
      # A redirection target is not consumption: `2>&1` tokenizes as `2>` `&` `1`.
      if [[ "${prev}" == *[\<\>] ]]; then
        prev="${token}"
        idx=$((idx + 1))
        continue
      fi
      case "${token}" in
        '&')
          amp=$((amp + 1))
          ((amp >= 2)) && return 0
          ;;
        '|')
          pipe=$((pipe + 1))
          ((pipe >= 2)) && return 0
          ;;
        'wc' | 'xargs') ((pipe >= 1)) && return 0 ;;
        ';' | '<NL>') break ;;
        *) amp=0 ;;
      esac
    fi
    prev="${token}"
    idx=$((idx + 1))
  done <<< "${tokens}"

  # `p=$(pgrep ...)`: the output is captured rather than printed.
  invocation_is_captured "${tokens}" "${target}" && return 0
  return 1
}

# shellcheck disable=SC2016
readonly WARN_MESSAGE='Note: this `pgrep --full` also matches the process running this very command.
The Bash tool executes commands as `bash -c ...`, so the search pattern appears in an ancestor
process command line and is always found. The result is therefore inflated by one, and an exit status
of 0 does not mean the target process is running. Add `--ignore-ancestors` if the count or the exit
status is being used for anything.'

# @description Build the deny reason for a deny kind.
# @arg $1 kind loop or kill
# @stdout the reason text
function deny_message() {
  local -r kind="$1"
  local preamble

  case "${kind}" in
    loop)
      # shellcheck disable=SC2016
      preamble='This loop can never exit. The Bash tool runs commands as `bash -c ...`, so the search
pattern is by construction part of an ancestor process command line. `pgrep --full` matches that
ancestor, the loop always sees a live process, and it spins until something kills it.'
      ;;
    kill)
      # shellcheck disable=SC2016
      preamble='This matches the invoking shell itself. The Bash tool runs commands as `bash -c ...`,
so the search pattern is part of an ancestor process command line, and killing that match terminates
the session shell.'
      ;;
    *)
      preamble='This pgrep matches its own ancestor process.'
      ;;
  esac

  # shellcheck disable=SC2016
  printf '%s\n\n%s\n' "${preamble}" 'Three fixes, in order of preference:

1. Do not poll. Use `kill -0 "$pid"`, a PID file, or let the background task notification wake you --
   completion re-invokes the model automatically. Polling is the root cause; this is a symptom.
2. `pgrep --ignore-ancestors --full <pattern>` excludes the `bash -c` ancestor.
3. `pgrep --full "[p]attern"` hides the needle from its own regex, but only when the bare literal
   appears NOWHERE ELSE in the same command. A second copy in the same call silently defeats it.

If this command writes text that CONTAINS such an example rather than running one, use the Write tool
instead of a heredoc; this guard only inspects Bash commands.'
}

# @description Classify a Bash command string.
# @arg $1 command the command string
# @stdout allow, warn, deny:loop, or deny:kill
function classify_command() {
  local -r command="$1"
  if [[ "${command}" != *pgrep* && "${command}" != *pkill* ]]; then
    printf 'allow\n'
    return 0
  fi
  local tokens
  tokens="$(scan_command "${command}")"
  local verdict='allow'
  local idx offset name args operand context
  while IFS=$'\t' read -r idx offset name; do
    [[ -z "${idx}" ]] && continue
    args="$(invocation_args "${tokens}" "${idx}")"
    has_flag "${args}" '--full' 'f' || continue
    has_flag "${args}" '--ignore-ancestors' 'A' && continue
    operand="$(pattern_operand "${command}" "${args}")"
    bracket_mitigation_holds "${command}" "${operand}" && continue
    if [[ "${name}" == 'pkill' ]] || feeds_a_kill "${tokens}" "${idx}"; then
      printf 'deny:kill\n'
      return 0
    fi
    context="$(loop_context "${tokens}" "${idx}")"
    case "${context}" in
      cond)
        printf 'deny:loop\n'
        return 0
        ;;
      body)
        if result_is_consumed "${tokens}" "${idx}" "${args}" \
          && body_has_terminator "${tokens}" "${idx}"; then
          printf 'deny:loop\n'
          return 0
        fi
        ;;
    esac
    result_is_consumed "${tokens}" "${idx}" "${args}" && verdict='warn'
  done <<< "$(find_invocations "${tokens}")"
  printf '%s\n' "${verdict}"
}

# @description Entry point.
# @arg $@ args pass --self-test to run the built-in table
function main() {
  if [[ "${1:-}" == '--self-test' ]]; then
    # The table reports failure by returning 1; the ERR trap would swallow it.
    trap - ERR
    run_self_test
    return
  fi

  if ! command -v jq > /dev/null 2>&1; then
    printf '{"systemMessage":"%s"}\n' \
      "${HOOK_NAME}: jq not found on PATH; the pgrep poll-loop guard is INACTIVE for this command."
    return 0
  fi

  # Without these two the scanner call dies, the ERR trap allows, and the guard is
  # silently dead -- which is the exact failure mode this hook exists to prevent.
  # Fail open loudly, the same way the jq branch does.
  if ! command -v awk > /dev/null 2>&1; then
    printf '{"systemMessage":"%s"}\n' \
      "${HOOK_NAME}: awk not found on PATH; the pgrep poll-loop guard is INACTIVE for this command."
    return 0
  fi

  if [[ ! -r "${SCANNER}" ]]; then
    printf '{"systemMessage":"%s"}\n' \
      "${HOOK_NAME}: scanner pgrep-scan.awk is missing; the pgrep poll-loop guard is INACTIVE for this command."
    return 0
  fi

  local input
  input="$(cat)"

  local tool_name
  tool_name="$(jq --raw-output '.tool_name // empty' <<< "${input}")"
  if [[ "${tool_name}" != 'Bash' ]]; then
    emit_allow
    return 0
  fi

  local command
  command="$(jq --raw-output '.tool_input.command // empty' <<< "${input}")"

  local decision
  decision="$(classify_command "${command}")"
  case "${decision}" in
    deny:*)
      emit_deny "$(deny_message "${decision#deny:}")"
      ;;
    warn)
      emit_warn "${WARN_MESSAGE}"
      ;;
    *)
      emit_allow
      ;;
  esac
}

main "$@"
