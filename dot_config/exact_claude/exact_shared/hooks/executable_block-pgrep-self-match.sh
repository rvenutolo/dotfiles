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

# @description True when a token is a shell variable-assignment word (`FOO=bar`, `LC_ALL=C`, ...).
#              Tested against the raw token rather than its basename: unlike a prefix command, an
#              assignment's value routinely contains a `/` (`PATH=/usr/bin cmd`), and stripping to
#              the basename there would corrupt the match.
# @arg $1 token the token to test
# @exitcode 0 the token is a shell assignment word
# @exitcode 1 it is not
function is_assignment_word() {
  local -r token="$1"
  [[ "${token}" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]
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

# @description Tokenize a command, masking quoted regions.
# @arg $1 command the command string
# @stdout offset and token pairs, separated by tab
function scan_command() {
  local -r command="$1"
  printf '%s' "${command}" | LC_ALL=C awk -f "${SCANNER}"
}

# @description Locate pgrep/pkill invocations that sit in command position. A quoted mention such as
#              `grep -r "until ! pgrep --full"` yields nothing, because the scanner masked it. A
#              leading run of prefix words (`sudo`, `command`, ...) keeps command position, and the
#              token is matched on its basename so `/usr/bin/pgrep` counts. A leading run of shell
#              assignment words (`FOO=bar pgrep ...`, `LC_ALL=C env FOO=bar pkill ...`) does too:
#              `NAME=value` in front of a command is ordinary shell, not an argument, and without
#              this the assignment hides the invocation from the whole scan -- not just from the
#              kill/loop tiers -- because `at_cmd` drops to 0 and the pgrep/pkill token itself is
#              never recorded.
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
    elif ((at_cmd == 1)) && { is_prefix_command "${word}" || is_assignment_word "${token}"; }; then
      # Only a prefix or assignment that is itself in command position chains: in
      # `git command x` the word `command` is an argument, not a prefix.
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
#              nor a redirection. Once a bare -- end-of-options terminator is seen, every later token
#              is a pattern candidate regardless of a leading dash -- only an exact redirection
#              operator is still excluded. Sliced out of the raw command by offset so the original
#              quoting survives, then one surrounding quote pair is stripped.
# @arg $1 command the raw command string
# @arg $2 args newline-separated "<offset>\t<token>" lines
# @stdout the operand with surrounding quotes removed, or empty
function pattern_operand() {
  local -r command="$1" args="$2"
  local operand_offset='' operand_length=0 skip=0 past_terminator=0 offset token value_option
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((skip == 1)); then
      skip=0
      continue
    fi
    if ((past_terminator == 1)); then
      if [[ "${token}" == '>' || "${token}" == '<' || "${token}" == '>>' ]]; then
        skip=1
      else
        operand_offset="${offset}"
        operand_length="${#token}"
      fi
      continue
    fi
    if [[ "${token}" == '--' ]]; then
      past_terminator=1
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
#              so a self-matching pgrep there pins no termination test. `$(`, a backtick, and a plain
#              `(` each push a scope-barrier marker so that a loop entirely inside one cannot pop, or
#              be popped by, a loop spanning the enclosing command: a stray `do`/`done` inside a
#              substitution (whether from a real nested loop or just literal text, such as an echoed
#              "done") is bounded by its own barrier and can never reach past it. The marker is
#              transparent when reading the context AT the target index, though: an invocation that is
#              simply inside a substitution with no loop of its own still belongs to whatever cond/body
#              span encloses that substitution, which is why `until [ -z "$(pgrep --full x)" ]; do ...`
#              still reports `cond` -- the lookup skips barrier markers to find the nearest real span.
# @arg $1 tokens the token stream from scan_command
# @arg $2 target index of the invocation token
# @stdout none, cond, or body
function loop_context() {
  local -r tokens="$1" target="$2"
  local -a stack=()
  local idx=0 at_cmd=1 dollar=0 offset token
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((idx == target)); then
      local i="$((${#stack[@]} - 1))" found='none'
      while ((i >= 0)); do
        case "${stack[i]}" in
          cond)
            found='cond'
            break
            ;;
          body)
            found='body'
            break
            ;;
          head)
            found='none'
            break
            ;;
          *) i=$((i - 1)) ;;
        esac
      done
      printf '%s\n' "${found}"
      return 0
    fi
    if ((at_cmd == 1)); then
      case "${token}" in
        'while' | 'until') stack+=('cond') ;;
        'for' | 'select') stack+=('head') ;;
        'do')
          if ((${#stack[@]} > 0)) && [[ "${stack[${#stack[@]} - 1]}" == 'cond' ||
            "${stack[${#stack[@]} - 1]}" == 'head' ]]; then
            unset 'stack[${#stack[@]}-1]'
          fi
          stack+=('body')
          ;;
        'done')
          if ((${#stack[@]} > 0)) && [[ "${stack[${#stack[@]} - 1]}" == 'body' ]]; then
            unset 'stack[${#stack[@]}-1]'
          fi
          ;;
      esac
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

# @description True when the do/done body belonging to the `for`/`select`/`while`/`until` head at
#              head_idx contains `kill` in command position. Covers two idioms where `kill` is not
#              adjacent to the invocation in the token stream at all, so the rest of this guard's
#              kill detection (which looks for `kill` next to or piped from the invocation) cannot
#              see it: `for pid in $(pgrep -f java); do kill "$pid"; done` (head_idx is the `in`
#              token, invoked from the backward scan) and `pgrep -f java | while read -r p; do kill
#              "$p"; done` (head_idx is the `while` token itself, invoked from the forward pipeline
#              scan). Either way this walks forward past the head's condition/iterable list to find
#              the matching `do`, then scans that body (respecting nested do/done depth, the way
#              body_has_terminator does) for a command-position `kill`. A loop whose body never
#              kills (`for f in $(pgrep -f java); do echo "$f"; done`) must return 1 so the caller
#              falls through to the ordinary warn path.
# @arg $1 tokens_var name of the caller's token array
# @arg $2 head_idx index of the `in`/`while`/`until` token whose body's `do` follows
# @exitcode 0 the loop body kills
# @exitcode 1 it does not, or no body was found
function loop_body_has_kill() {
  local -n toks="$1"
  local -r head_idx="$2"
  local idx=$((head_idx + 1)) token found_do=0 body_depth=1 at_cmd=1
  local -a pstack=()

  # Walk the condition/iterable list to the `do` that opens this loop's body,
  # tracking any nested `$(...)`/backtick/subshell depth so a `do` inside one
  # of those (a real nested loop, or just literal text) is not mistaken for
  # this loop's.
  while ((idx < ${#toks[@]})); do
    token="${toks[idx]}"
    case "${token}" in
      '(') pstack+=('p') ;;
      ')') ((${#pstack[@]} > 0)) && unset 'pstack[${#pstack[@]}-1]' ;;
      '`')
        if ((${#pstack[@]} > 0)) && [[ "${pstack[${#pstack[@]} - 1]}" == 'b' ]]; then
          unset 'pstack[${#pstack[@]}-1]'
        else
          pstack+=('b')
        fi
        ;;
    esac
    if ((${#pstack[@]} == 0)) && [[ "${token}" == 'do' ]]; then
      found_do=1
      idx=$((idx + 1))
      break
    fi
    idx=$((idx + 1))
  done
  ((found_do == 1)) || return 1

  while ((idx < ${#toks[@]})); do
    token="${toks[idx]}"
    if ((at_cmd == 1)); then
      case "${token}" in
        'do') body_depth=$((body_depth + 1)) ;;
        'done')
          body_depth=$((body_depth - 1))
          ((body_depth == 0)) && return 1
          ;;
        'kill') return 0 ;;
      esac
    fi
    if is_operator "${token}" || is_keyword "${token}"; then at_cmd=1; else at_cmd=0; fi
    idx=$((idx + 1))
  done
  return 1
}

# xargs options that take their value as a SEPARATE word, so that word is data
# rather than the command xargs will run. Only options whose argument is
# mandatory belong here. GNU spells three of these with an OPTIONAL argument
# (`-e`, `-i`, `-l`), which the shell can only attach (`-i%`), never separate --
# so `xargs -i kill {}` runs kill, and listing them would swallow the very
# command word this scan exists to find. Over-consuming hides a kill; under-
# consuming only costs a warn, so the doubtful cases stay out.
# `-J` is BSD/macOS-only and has no GNU meaning, so it is safe to carry here.
readonly -a XARGS_VALUE_OPTIONS=(
  '-a' '--arg-file' '-d' '--delimiter' '-E' '-I' '-J' '-L' '-n' '--max-args'
  '-P' '--max-procs' '-s' '--max-chars' '--process-slot-var'
)

# @description True when a token is an xargs option that consumes the following word as its value.
#              Matches the exact option only: an attached spelling (`-n1`, `--max-args=1`) carries
#              its own value and must not also eat the next word.
# @arg $1 token the token to test
# @exitcode 0 the token is such an option
# @exitcode 1 it is not
function is_xargs_value_option() {
  local -r token="$1"
  local option
  for option in "${XARGS_VALUE_OPTIONS[@]}"; do
    [[ "${token}" == "${option}" ]] && return 0
  done
  return 1
}

# @description True when an invocation's output is piped into a kill, or when the invocation is
#              itself substituted into a kill's argument list (`kill $(pgrep ...)` and the backtick
#              equivalent). The forward pipeline scan requires `kill` to head a pipeline segment, or
#              to follow an `xargs` that heads one, with flags and prefix words allowed in between:
#              `pgrep --full x | grep -i kill` merely searches for the word and kills nothing. A
#              pipeline segment headed by `while`/`until` (`pgrep -f java | while read -r p; do kill
#              "$p"; done`) defers to loop_body_has_kill rather than being written off as `other`. The
#              backward scan's `(` check also excludes an array literal (`arr=(kill $(...))`): the
#              `(` there opens a list of words rather than a subshell, so `kill` inside it is never
#              invoked. Its `in` case defers to loop_body_has_kill the same way, for `for pid in
#              $(pgrep -f java); do kill "$pid"; done` -- but only once it confirms the `in` actually
#              heads a for/select construct, so an unrelated argument word `in` (`echo in $(...)`)
#              cannot be mistaken for one and misattribute a later, unrelated loop's kill.
# @arg $1 tokens_var name of the caller's token array (built once by classify_command; every
#              invocation in the same command reuses it rather than re-parsing the token stream)
# @arg $2 target index of the invocation token
# @exitcode 0 output feeds a kill
# @exitcode 1 it does not
function feeds_a_kill() {
  local -n toks="$1"
  local -r target="$2"
  local idx segment='none' word xargs_skip=0
  for ((idx = target + 1; idx < ${#toks[@]}; idx++)); do
    word="${toks[idx]##*/}"
    case "${word}" in
      '|')
        segment='head'
        xargs_skip=0
        ;;
      ';' | '<NL>') break ;;
      *)
        case "${segment}" in
          head)
            if [[ "${word}" == 'kill' ]]; then
              return 0
            elif [[ "${word}" == 'xargs' ]]; then
              segment='xargs'
              xargs_skip=0
            elif [[ "${word}" == 'while' || "${word}" == 'until' ]]; then
              loop_body_has_kill "$1" "${idx}" && return 0
              segment='other'
            elif ! is_prefix_command "${word}"; then
              segment='other'
            fi
            ;;
          xargs)
            if ((xargs_skip == 1)); then
              # Value word belonging to the option before it, not a command.
              xargs_skip=0
            elif [[ "${word}" == 'kill' ]]; then
              return 0
            elif [[ "${word}" == '{' || "${word}" == '}' ]]; then
              : # `-I{}` placeholder braces, not a new command word
            elif is_xargs_value_option "${word}"; then
              xargs_skip=1
            elif [[ "${word}" != -* ]] && ! is_prefix_command "${word}"; then
              segment='other'
            fi
            ;;
        esac
        ;;
    esac
  done

  # Backward form: `kill $(pgrep ...)`, `kill -9 $(pgrep ...)`, and the backtick
  # equivalent. Here `kill` precedes the invocation, so the forward scan cannot
  # see it. Skip the substitution punctuation and any flags on the way back, then
  # require the `kill` to be in command position -- otherwise `echo kill $(...)`,
  # where `kill` is merely an argument word, would be denied. A value word that
  # belongs to a preceding `-s`/`--signal` (`kill -s TERM $(pgrep ...)`) is also
  # skipped rather than treated as an unrecognized stop word: it is recognized by
  # peeking at the token immediately before it, since scanning backward means the
  # value is reached before its flag. Walking further back past `kill` to confirm
  # command position also accepts a shell assignment word (`FOO=bar kill $(...)`),
  # matching find_invocations's forward treatment of the same prefix.
  local k=$((target - 1)) m
  while ((k >= 0)); do
    word="${toks[k]##*/}"
    case "${word}" in
      '$' | '(' | '`') ;;
      -*) ;;
      'kill')
        m=$((k - 1))
        while ((m >= 0)); do
          if is_prefix_command "${toks[m]##*/}" || is_assignment_word "${toks[m]}"; then
            m=$((m - 1))
            continue
          fi
          # `(` restores command position for a real subshell or grouping
          # construct, but `name=(...)` is an array literal: the `(` merely
          # opens a list of words, and a `kill` immediately inside it is
          # never invoked. The token right before the `(` ending in `=` is
          # what tells the two apart.
          if [[ "${toks[m]}" == '(' ]] && ((m > 0)) && [[ "${toks[m - 1]}" == *= ]]; then
            return 1
          fi
          if is_operator "${toks[m]}" || is_keyword "${toks[m]}"; then return 0; fi
          return 1
        done
        return 0
        ;;
      'in')
        # A bare `in` is only a for/select head -- and thus worth deferring to
        # loop_body_has_kill -- when the token two back (past the loop
        # variable) is actually `for`/`select`. Otherwise `in` is just an
        # ordinary argument word (`echo in $(...)`), and the forward walk to
        # a `do` in loop_body_has_kill could cross into an unrelated later
        # loop's body and misattribute its kill to this invocation.
        if ((k >= 2)) && { [[ "${toks[k - 2]}" == 'for' ]] || [[ "${toks[k - 2]}" == 'select' ]]; }; then
          loop_body_has_kill "$1" "${k}" && return 0
        fi
        return 1
        ;;
      *)
        if ((k > 0)) \
          && { [[ "${toks[k - 1]##*/}" == '-s' ]] || [[ "${toks[k - 1]##*/}" == '--signal' ]]; }; then
          : # signal-name value word for -s/--signal, not a stop word
        else
          return 1
        fi
        ;;
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
# @arg $1 tokens_var name of the caller's token array, built once by classify_command
# @arg $2 target index of the invocation token
# @exitcode 0 the invocation is inside a command substitution
# @exitcode 1 it is not
function invocation_is_captured() {
  local -n toks="$1"
  local -r target="$2"
  local -a stack=()
  local idx dollar=0 token entry
  for ((idx = 0; idx <= target; idx++)); do
    token="${toks[idx]}"
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
  done
  return 1
}

# @description True when the command immediately after an invocation, in the same list, reads `$?`.
#              That is a consumption of the exit status exactly like `&&` or an enclosing `if`, and
#              the forward scan in result_is_consumed cannot see it because it stops at the `;` or
#              newline that ends the invocation's own simple command.
#
#              The `$?` test runs against the RAW command text rather than the token stream, because
#              the scanner masks a double-quoted `$?` (`echo "exit=$?"`) down to filler -- the very
#              shape #155 recorded -- and the tokens would show nothing. What the tokens do supply,
#              and a raw substring search could not, are mask-aware separator offsets: only a `;` or
#              newline the scanner saw as real code delimits the segment, so a `;` inside a quoted
#              pattern cannot split it.
#
#              Scope is deliberately one command, not the rest of the list: in `pgrep --full x; echo
#              hi; rc=$?` the status belongs to `echo`, and warning there would be wrong. The cost of
#              reading raw text is a single-quoted literal `$?` counting as a read; that direction
#              only over-warns, and no realistic command writes one right after a pgrep.
# @arg $1 command the raw command string
# @arg $2 tokens the token stream from scan_command
# @arg $3 target index of the invocation token
# @exitcode 0 the following command reads the exit status
# @exitcode 1 it does not
function next_command_reads_status() {
  local -r command="$1" tokens="$2" target="$3"
  local idx=0 offset token start=-1 end=-1
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    if ((idx > target)) && { [[ "${token}" == ';' ]] || [[ "${token}" == '<NL>' ]]; }; then
      if ((start < 0)); then
        start=$((offset + 1))
      else
        end="${offset}"
        break
      fi
    fi
    idx=$((idx + 1))
  done <<< "${tokens}"
  ((start < 0)) && return 1
  ((end < 0)) && end="${#command}"
  ((end <= start)) && return 1
  [[ "${command:start:end-start}" == *'$?'* ]]
}

# @description True when an invocation's result is read as a boolean, a count, or captured into a
#              variable, rather than merely displayed. Only then can the silent off-by-one produce a
#              wrong conclusion. Five shapes count: pgrep's own `--count` / `-c`; an enclosing `if`
#              or `elif`, or a leading `!`, which read the exit status as a boolean; a following
#              `&&`, `||`, `| wc` or `| xargs`; sitting inside a command substitution; and the next
#              command in the list reading `$?`, which next_command_reads_status handles. A
#              redirection target is not consumption: `2>&1` tokenizes as `2>`, `&`, `1`, and a lone
#              trailing `&` is backgrounding rather than a boolean operator.
# @arg $1 tokens_var name of the caller's token array, built once by classify_command
# @arg $2 target index of the invocation token
# @arg $3 args the invocation's argument lines
# @arg $4 command the raw command string, for the `$?` check
# @arg $5 tokens the token stream from scan_command, for the `$?` check
# @exitcode 0 the result is consumed
# @exitcode 1 the result is only displayed
function result_is_consumed() {
  local -n toks="$1"
  local -r target="$2" args="$3" command="$4" tokens="$5"
  local offset token
  while IFS=$'\t' read -r offset token; do
    [[ -z "${token}" ]] && continue
    [[ "${token}" == '--count' ]] && return 0
    if [[ "${token}" == -[a-zA-Z]* && "${token}" != --* && "${token}" == *c* ]]; then return 0; fi
  done <<< "${args}"

  # An enclosing `if` / `elif`, or a negation, reads the exit status as a boolean.
  # Walk back over prefix words so `if sudo pgrep --full x` still counts.
  local k=$((target - 1)) word
  while ((k >= 0)); do
    word="${toks[k]##*/}"
    case "${word}" in
      'if' | 'elif' | '!') return 0 ;;
      *) is_prefix_command "${word}" || break ;;
    esac
    k=$((k - 1))
  done

  local idx prev="${toks[target]}" amp=0 pipe=0
  for ((idx = target + 1; idx < ${#toks[@]}; idx++)); do
    token="${toks[idx]}"
    # A redirection target is not consumption: `2>&1` tokenizes as `2>` `&` `1`.
    if [[ "${prev}" == *[\<\>] ]]; then
      prev="${token}"
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
    prev="${token}"
  done

  # `p=$(pgrep ...)`: the output is captured rather than printed.
  invocation_is_captured "$1" "${target}" && return 0

  # `pgrep --full x; rc=$?`: the status is read by the next command in the list.
  next_command_reads_status "${command}" "${tokens}" "${target}" && return 0
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
# @arg $2 tool the tool of the denying invocation, pgrep or pkill; defaults to pgrep
# @stdout the reason text
function deny_message() {
  local -r kind="$1"
  local -r tool="${2:-pgrep}"
  local preamble fixes

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

  if [[ "${kind}" == 'kill' ]]; then
    # Kill denials get targeting advice, not anti-polling advice, and the
    # examples name the tool that was actually invoked (#152).
    # shellcheck disable=SC2016
    fixes='Three fixes, in order of preference:

1. Kill by PID, not by pattern. Use a PID recorded when the process was started (`kill "$pid"`, a
   PID file), or probe liveness first with `kill -0 "$pid"`. Pattern-matching kills are the root
   cause; the self-match is a symptom.
2. `__TOOL__ --ignore-ancestors --full <pattern>` excludes the `bash -c` ancestor.
3. `__TOOL__ --full "[p]attern"` hides the needle from its own regex, but only when the bare literal
   appears NOWHERE ELSE in the same command. A second copy in the same call silently defeats it.

If this command writes text that CONTAINS such an example rather than running one, use the Write tool
instead of a heredoc; this guard only inspects Bash commands.'
    fixes="${fixes//__TOOL__/${tool}}"
  else
    # shellcheck disable=SC2016
    fixes='Three fixes, in order of preference:

1. Do not poll. Use `kill -0 "$pid"`, a PID file, or let the background task notification wake you --
   completion re-invokes the model automatically. Polling is the root cause; this is a symptom.
2. `pgrep --ignore-ancestors --full <pattern>` excludes the `bash -c` ancestor.
3. `pgrep --full "[p]attern"` hides the needle from its own regex, but only when the bare literal
   appears NOWHERE ELSE in the same command. A second copy in the same call silently defeats it.

If this command writes text that CONTAINS such an example rather than running one, use the Write tool
instead of a heredoc; this guard only inspects Bash commands.'
  fi

  printf '%s\n\n%s\n' "${preamble}" "${fixes}"
}

# @description Classify a Bash command string.
# @arg $1 command the command string
# @stdout allow, warn, or deny:loop / deny:kill followed by a tab and the invoked tool
function classify_command() {
  local -r command="$1"
  if [[ "${command}" != *pgrep* && "${command}" != *pkill* ]]; then
    printf 'allow\n'
    return 0
  fi
  local tokens
  tokens="$(scan_command "${command}")"

  # Parsed once and shared by every invocation in this command, instead of
  # each of feeds_a_kill / result_is_consumed / invocation_is_captured
  # re-parsing the full token stream from scratch per invocation. A command
  # with many invocations (a long chain of pgrep calls) made that rescan
  # quadratic; array indexing does not.
  local -a CMD_TOKENS=()
  local _ raw_token
  while IFS=$'\t' read -r _ raw_token; do
    [[ -z "${raw_token}" ]] && continue
    CMD_TOKENS+=("${raw_token}")
  done <<< "${tokens}"

  local verdict='allow'
  local idx offset name args operand context
  while IFS=$'\t' read -r idx offset name; do
    [[ -z "${idx}" ]] && continue
    args="$(invocation_args "${tokens}" "${idx}")"
    has_flag "${args}" '--full' 'f' || continue
    has_flag "${args}" '--ignore-ancestors' 'A' && continue
    operand="$(pattern_operand "${command}" "${args}")"
    bracket_mitigation_holds "${command}" "${operand}" && continue
    if [[ "${name}" == 'pkill' ]] || feeds_a_kill CMD_TOKENS "${idx}"; then
      printf 'deny:kill\t%s\n' "${name}"
      return 0
    fi
    context="$(loop_context "${tokens}" "${idx}")"
    case "${context}" in
      cond)
        printf 'deny:loop\t%s\n' "${name}"
        return 0
        ;;
      body)
        if result_is_consumed CMD_TOKENS "${idx}" "${args}" "${command}" "${tokens}" \
          && body_has_terminator "${tokens}" "${idx}"; then
          printf 'deny:loop\t%s\n' "${name}"
          return 0
        fi
        ;;
    esac
    result_is_consumed CMD_TOKENS "${idx}" "${args}" "${command}" "${tokens}" && verdict='warn'
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

  # One jq spawn instead of two, since it runs on every Bash call. The command
  # can contain literal tabs and newlines, which @tsv escapes as `\t` / `\n`
  # rather than emitting them raw -- raw newlines would split a single TSV
  # record across lines, and a raw tab would be indistinguishable from the
  # field separator. `printf '%b'` decodes exactly that escape set (`\\`,
  # `\t`, `\n`, `\r`) as a single left-to-right pass, which is what makes it
  # safe: every backslash jq emits is already paired, so there is no separate
  # unescape step that could reinterpret a decoded literal backslash.
  local tsv_line
  tsv_line="$(jq --raw-output '[(.tool_name // ""), (.tool_input.command // "")] | @tsv' <<< "${input}")"
  local tool_name command_escaped
  IFS=$'\t' read -r tool_name command_escaped <<< "${tsv_line}"
  if [[ "${tool_name}" != 'Bash' ]]; then
    emit_allow
    return 0
  fi

  local command
  command="$(printf '%b' "${command_escaped}")"

  local decision deny_tool
  IFS=$'\t' read -r decision deny_tool <<< "$(classify_command "${command}")"
  case "${decision}" in
    deny:*)
      emit_deny "$(deny_message "${decision#deny:}" "${deny_tool}")"
      ;;
    warn)
      emit_warn "${WARN_MESSAGE}"
      ;;
    *)
      emit_allow
      ;;
  esac
}

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
  # This row does not discriminate on its own -- the command also carries --full.
  # The two rows below it do: each has a lookalike and nothing else.
  $'pgrep --list-full --full java\tallow'
  $'until ! pgrep --list-full java; do sleep 5; done\tallow'
  $'until ! pgrep -- --full x; do sleep 5; done\tallow'
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

  # F7 -- everything after a bare `--` end-of-options terminator is a pattern,
  # not a flag. A displayed one-shot with no consuming context is still a
  # silent allow, same as any other bare full-match invocation; the case that
  # actually changes is a bracket class recognised only once `-x` is no
  # longer swallowed as a flag.
  $'pgrep --full -- -x\tallow'
  $'until ! pgrep --full -- "[u]nittest discover"; do sleep 5; done\tallow'

  # F8 -- an array literal's `(` restores command position for legitimate
  # reasons (grouping, subshells), but `arr=(...)` is not one of them: `kill`
  # immediately inside an array literal is a string element, never invoked.
  $'arr=(kill $(pgrep --full x))\twarn'

  # F9 -- a leading shell assignment word must not hide the invocation from
  # find_invocations. Without the fix these all read as if pgrep/pkill were
  # never called at all -- allow, not merely under-classified.
  $'until ! FOO=bar pgrep --full x; do sleep 5; done\tdeny:loop'
  $'LC_ALL=C pgrep --full x | xargs kill\tdeny:kill'
  $'FOO=bar pkill --full java\tdeny:kill'
  $'env FOO=bar pkill --full java\tdeny:kill'

  # F10 -- three kill idioms that used to reach only warn: the backward scan's
  # bare `in` used to abort instead of checking the for-loop body; `{`/`}`
  # (an xargs -I{} placeholder) used to reset the xargs segment to `other`
  # before the `kill` that followed it; and a `-s`/`--signal` value word (a
  # signal name, not punctuation) used to abort the backward scan before it
  # ever reached `kill`.
  $'for pid in $(pgrep -f java); do kill "$pid"; done\tdeny:kill'
  $'pgrep -f java | xargs -I{} kill {}\tdeny:kill'
  $'kill -s TERM $(pgrep -f java)\tdeny:kill'

  # F11 -- a pipeline segment headed by `while`/`until` used to be written off
  # as `other` on sight, so a kill in the loop body was never seen even though
  # it is at least as common as the already-denied `| xargs kill` form.
  $'pgrep -f java | while read -r p; do kill "$p"; done\tdeny:kill'

  # F12 -- a leading shell assignment word before `kill` in the backward
  # substitution-kill scan must chain command position the same way
  # find_invocations's forward scan already does for F9; without this the
  # substitution form escapes while the equivalent pkill form (F9) correctly
  # denies.
  $'FOO=bar kill $(pgrep -f java)\tdeny:kill'

  # F13 -- the backward scan's bare `in` case must confirm it actually heads
  # a for/select construct before deferring to loop_body_has_kill. Without
  # the check, `in` as a plain argument word lets the forward walk to `do`
  # cross the `;` boundary and misattribute an unrelated later loop's kill
  # to this substitution.
  $'echo in $(pgrep -f java); while true; do kill 1; done\twarn'

  # F14 (#155 entry 6) -- an xargs option and its value written as two words.
  # The xargs segment state tolerates any `-flag`, but the value word that
  # follows a separated option is a bare word, which used to reset the segment
  # to `other` and lose the `kill` behind it. The attached spellings
  # (`-n1`, `--max-args=1`) never had the problem, which is what made the gap
  # look narrower than it is: `xargs -n 1 kill` is an ordinary thing to write.
  $'pgrep -f java | xargs -n 1 kill\tdeny:kill'
  $'pgrep -f java | xargs --max-args 1 kill\tdeny:kill'
  $'pgrep -f java | xargs -P 4 kill\tdeny:kill'
  $'pgrep -f java | xargs -I % kill %\tdeny:kill'
  $'pgrep -f java | xargs --replace=% kill %\tdeny:kill'
  # The value word must be skipped, never treated as a command: a non-kill
  # command after a separated option must still reach only warn.
  $'pgrep -f java | xargs -n 1 echo\twarn'
  $'pgrep -f java | xargs -n 1 grep -i kill\twarn'
  # A flag that takes no value must not swallow the command word after it.
  $'pgrep -f java | xargs -r kill\tdeny:kill'
  $'pgrep -f java | xargs --no-run-if-empty kill\tdeny:kill'

  # F15 (#155 entry 5) -- a following command that reads `$?` consumes the
  # exit status just as surely as `&&` or an enclosing `if`, and the
  # off-by-one corrupts exactly that reading. The status is most often read
  # from the next command in the list, where the forward scan used to stop.
  $'pgrep --full x > /dev/null; echo "exit=$?"\twarn'
  $'pgrep --full x; rc=$?\twarn'
  $'pgrep --full x\necho $?\twarn'
  # Scoped to the command immediately after: a `$?` further down the list
  # belongs to some other command's status, and must not warn.
  $'pgrep --full x; echo hi\tallow'
  $'pgrep --full x; echo hi; rc=$?\tallow'
  # The `$?` poll loop this unlocks: a body-context invocation whose status is
  # read into a variable and tested for a `break`. Every ingredient of
  # deny:loop was present except the consumption test, so it used to allow.
  $'while true; do pgrep --full x; rc=$?; [[ $rc -eq 0 ]] && break; sleep 5; done\tdeny:loop'
)

# Message-content rows: command TAB field TAB mode TAB needle. Fields: reason
# (permissionDecisionReason of a deny), context (additionalContext of a
# warn), or decision (permissionDecision, exact match via mode equals, with
# "none" standing in for an absent field). These guard the copy, its field
# wiring (#151, #152), and the decision wiring (#158); verdicts are owned by
# SELF_TEST_CASES.
readonly -a MESSAGE_TEST_CASES=(
  # Kill denial via pkill: targeting advice, tool named correctly, no polling diagnosis.
  $'pkill --full java\treason\tlacks\tPolling is the root cause'
  $'pkill --full java\treason\tcontains\tKill by PID, not by pattern'
  $'pkill --full java\treason\tcontains\tpkill --ignore-ancestors'
  $'pkill --full java\treason\tlacks\tpgrep --ignore-ancestors'
  # Kill denial via pgrep piped into kill: examples keep naming pgrep.
  $'pgrep --full x | xargs kill\treason\tcontains\tpgrep --ignore-ancestors'
  $'pgrep --full x | xargs kill\treason\tcontains\tKill by PID, not by pattern'
  # Loop denial: anti-polling advice stays, and a mitigation is named.
  $'while pgrep --full x > /dev/null; do sleep 5; done\treason\tcontains\tDo not poll'
  $'while pgrep --full x > /dev/null; do sleep 5; done\treason\tcontains\t--ignore-ancestors'
  # Warn: the inflated-count explanation reaches additionalContext.
  $'pgrep --full x | wc -l\tcontext\tcontains\tinflated by one'
  # Decision wiring (#158): the emitted permissionDecision per tier. Without
  # these rows, flipping deny to allow in emit_deny keeps every other row
  # green while the guard stops blocking. "none" asserts the {} passthrough.
  $'pkill --full java\tdecision\tequals\tdeny'
  $'pgrep --full x | wc -l\tdecision\tequals\tallow'
  $'ls\tdecision\tequals\tnone'
)

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
  assert_equals 'operand after -- is not swallowed as a flag' '-x' \
    "$(pattern_probe 'pgrep --full -- -x')" || failures=$((failures + 1))

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
  # A `done` inside a command substitution IS in command position -- unlike the
  # argument-word case above -- but it must still be unable to pop a span that
  # encloses the substitution. Without a scope barrier this `done` pops the
  # outer body early, and the invocation reads as outside every loop.
  # shellcheck disable=SC2016
  assert_equals 'a done inside a substitution cannot pop the enclosing body span' 'body' \
    "$(context_probe 'while true; do echo "$(: ; done)"; pgrep --full x || break; sleep 5; done')" \
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

  assert_equals 'tsv round-trip preserves a literal tab and newline' \
    $'a\tb\nc' "$(tsv_roundtrip_probe $'a\tb\nc')" || failures=$((failures + 1))

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

# @description Self-test helper: round-trip a command string through the same jq @tsv
#              extraction and printf %b decoding that main() uses, to confirm a literal tab and
#              newline in the command survive it byte for byte. jq escapes an actual tab as `\t`
#              and an actual newline as `\n` so the record stays on one TSV line; decoding the
#              wrong sequences, or in the wrong order, corrupts token boundaries silently rather
#              than erroring.
# @arg $1 command the command string to round-trip
# @stdout the decoded command
function tsv_roundtrip_probe() {
  local -r command="$1"
  local input tsv_line
  input="$(jq --null-input --arg cmd "${command}" '{tool_name: "Bash", tool_input: {command: $cmd}}')"
  tsv_line="$(jq --raw-output '[(.tool_name // ""), (.tool_input.command // "")] | @tsv' <<< "${input}")"
  local tool_name command_escaped
  IFS=$'\t' read -r tool_name command_escaped <<< "${tsv_line}"
  printf '%b' "${command_escaped}"
}

# @description Self-test helper: compute the token stream, the first invocation's index, and its
#              argument lines for a command -- the common preamble every probe below needs before
#              calling the function it actually exercises.
# @arg $1 command the command string
# @arg $2 tokens_var name of the caller's variable to receive the token stream
# @arg $3 idx_var name of the caller's variable to receive the invocation index
# @arg $4 args_var name of the caller's variable to receive the argument lines
function first_invocation() {
  local -r command="$1"
  local -n tokens_out="$2" idx_out="$3" args_out="$4"
  tokens_out="$(scan_command "${command}")"
  idx_out="$(find_invocations "${tokens_out}" | head --lines=1 | cut --fields=1)"
  # shellcheck disable=SC2034 # write-only output param; the caller reads it through the nameref
  args_out="$(invocation_args "${tokens_out}" "${idx_out}")"
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
  local tokens idx args
  first_invocation "${command}" tokens idx args
  if has_flag "${args}" "${long}" "${short}"; then printf 'yes\n'; else printf 'no\n'; fi
}

# @description Self-test helper: the pattern operand of the first invocation.
# @arg $1 command the command string
# @stdout the operand, or empty
function pattern_probe() {
  local -r command="$1"
  local tokens idx args
  first_invocation "${command}" tokens idx args
  pattern_operand "${command}" "${args}"
}

# @description Self-test helper: does the bracket mitigation hold?
# @arg $1 command the command string
# @stdout yes or no
function bracket_probe() {
  local -r command="$1"
  local tokens idx args
  first_invocation "${command}" tokens idx args
  local operand
  operand="$(pattern_operand "${command}" "${args}")"
  if bracket_mitigation_holds "${command}" "${operand}"; then printf 'yes\n'; else printf 'no\n'; fi
}

# @description Self-test helper: loop context of the first invocation.
# @arg $1 command the command string
# @stdout none, cond, or body
function context_probe() {
  local -r command="$1"
  local tokens idx args
  first_invocation "${command}" tokens idx args
  loop_context "${tokens}" "${idx}"
}

# @description Self-test helper: does the loop body enclosing the first invocation
#              contain a break, exit or return?
# @arg $1 command the command string
# @stdout yes or no
function terminator_probe() {
  local -r command="$1"
  local tokens idx args
  first_invocation "${command}" tokens idx args
  if body_has_terminator "${tokens}" "${idx}"; then printf 'yes\n'; else printf 'no\n'; fi
}

# @description Run the message-content table end-to-end: feed real PreToolUse
#              JSON through main and assert on the emitted output. reason and
#              context rows substring-match permissionDecisionReason /
#              additionalContext; decision rows exact-match
#              permissionDecision, with "none" standing in for an absent
#              field. An empty extracted reason/context fails the row
#              regardless of mode, so a lacks row cannot pass vacuously
#              against a missing message or the wrong field. A malformed row
#              (empty needle, unrecognised field or mode, or a field/mode
#              pairing outside the grammar) fails instead of passing
#              vacuously — IFS collapses consecutive tabs, so a blanked
#              middle field surfaces here as a bad field/mode, not a silent
#              pass.
# @noargs
# @exitcode 0 all rows matched
# @exitcode 1 at least one row mismatched or malformed
function run_message_tests() {
  if ! command -v jq > /dev/null 2>&1; then
    printf 'FAIL(message): jq missing; message cases not run\n' >&2
    return 1
  fi
  local failures=0
  local case_line command field mode needle json out text ok
  for case_line in "${MESSAGE_TEST_CASES[@]}"; do
    IFS=$'\t' read -r command field mode needle <<< "${case_line}"
    ok=1
    if [[ -z "${needle}" ]]; then
      ok=0
    fi
    case "${field}" in
      reason | context | decision) ;;
      *) ok=0 ;;
    esac
    case "${mode}" in
      contains | lacks | equals) ;;
      *) ok=0 ;;
    esac
    # equals is exclusively the decision mode and vice versa.
    if [[ "${field}" == 'decision' && "${mode}" != 'equals' ]] \
      || [[ "${field}" != 'decision' && "${mode}" == 'equals' ]]; then
      ok=0
    fi
    if ((ok == 0)); then
      printf 'FAIL(message): malformed row: %s\n' "${case_line//$'\t'/<TAB>}" >&2
      failures=$((failures + 1))
      continue
    fi
    json="$(jq --null-input --arg cmd "${command}" '{tool_name: "Bash", tool_input: {command: $cmd}}')"
    out="$(main <<< "${json}")"
    case "${field}" in
      reason)
        text="$(jq --raw-output '.hookSpecificOutput.permissionDecisionReason // ""' <<< "${out}")"
        ;;
      context)
        text="$(jq --raw-output '.hookSpecificOutput.additionalContext // ""' <<< "${out}")"
        ;;
      decision)
        text="$(jq --raw-output '.hookSpecificOutput.permissionDecision // "none"' <<< "${out}")"
        ;;
    esac
    ok=1
    if [[ "${field}" != 'decision' && -z "${text}" ]]; then
      ok=0
    elif [[ "${mode}" == 'contains' && "${text}" != *"${needle}"* ]]; then
      ok=0
    elif [[ "${mode}" == 'lacks' && "${text}" == *"${needle}"* ]]; then
      ok=0
    elif [[ "${mode}" == 'equals' && "${text}" != "${needle}" ]]; then
      ok=0
    fi
    if ((ok == 0)); then
      printf 'FAIL(message): %s\n  field: %s  mode: %s  needle: %s\n  text: %.120s\n' \
        "${command}" "${field}" "${mode}" "${needle}" "${text}" >&2
      failures=$((failures + 1))
    fi
  done
  ((failures == 0))
}

# @description Sweep every deny-expected SELF_TEST_CASES row through main and
#              assert the --ignore-ancestors mitigation is named in each
#              permissionDecisionReason (#158). MESSAGE_TEST_CASES pins the
#              full copy for representative commands; this guards the
#              mitigation invariant across the whole deny surface.
# @noargs
# @exitcode 0 every deny reason names the mitigation
# @exitcode 1 at least one deny reason omits it
function run_deny_sweep() {
  if ! command -v jq > /dev/null 2>&1; then
    printf 'FAIL(sweep): jq missing; deny sweep not run\n' >&2
    return 1
  fi
  local failures=0
  local case_line command expected json out reason
  for case_line in "${SELF_TEST_CASES[@]}"; do
    command="${case_line%%$'\t'*}"
    expected="${case_line##*$'\t'}"
    if [[ "${expected}" != deny:* ]]; then
      continue
    fi
    json="$(jq --null-input --arg cmd "${command}" '{tool_name: "Bash", tool_input: {command: $cmd}}')"
    out="$(main <<< "${json}")"
    reason="$(jq --raw-output '.hookSpecificOutput.permissionDecisionReason // ""' <<< "${out}")"
    if [[ "${reason}" != *'--ignore-ancestors'* ]]; then
      printf 'FAIL(sweep): deny reason lacks --ignore-ancestors: %s\n  text: %.120s\n' \
        "${command//$'\n'/\\n}" "${reason}" >&2
      failures=$((failures + 1))
    fi
  done
  ((failures == 0))
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
  if ! run_message_tests; then
    failures=$((failures + 1))
  fi
  if ! run_deny_sweep; then
    failures=$((failures + 1))
  fi
  local case_line expected actual command
  for case_line in "${SELF_TEST_CASES[@]}"; do
    command="${case_line%%$'\t'*}"
    expected="${case_line##*$'\t'}"
    actual="$(classify_command "${command}")"
    # Verdict rows assert the kind alone; the tool field after the tab is
    # asserted end-to-end by MESSAGE_TEST_CASES, which fail if it is wrong.
    actual="${actual%%$'\t'*}"
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
  printf 'all %d self-test cases, %d message cases, and the deny sweep passed\n' \
    "${#SELF_TEST_CASES[@]}" "${#MESSAGE_TEST_CASES[@]}"
}

main "$@"
