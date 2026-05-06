- Use `#!/usr/bin/env bash`
- Use `set -Eeuo pipefail` (the `-E` is required so the `ERR` trap inherits into shell functions and command substitutions)
- Use `[[ ]]` over `[ ]`
- Use `(( ))` for arithmetic; never `let` or `expr`
- Use long options in commands (e.g., `cut --delimiter` not `cut -d`)
- Quote all variable expansions: `"${var}"` not `$var`
- Use `${var}` brace syntax for all variables EXCEPT single-character shell specials and positional parameters (`$?`, `$#`, `$$`, `$!`, `$@`, `$*`, `$1`–`$9`) — leave those unbraced. Positionals `${10}` and above still require braces.
- Quote command substitutions: `"$(cmd)"`
- Single-quote string literals when no expansion is needed: `'/dev/null'`, `'/etc/os-release'`, `'y'`. Reserve double quotes for expansion.
- Do not quote numeric option arguments: `--fields=1`, `--max-args=1` (not `--fields='1'`)
- Use `$(...)` not backticks
- Indent with 2 spaces; never tabs
- Constants and config: `readonly` and `UPPER_SNAKE_CASE` at top of script
- For script-level values derived from positional args, declare `readonly NAME="$1"` immediately after arg-count validation (still `UPPER_SNAKE_CASE` if treated as a constant for the rest of the script)
- Use `case ... in PATTERN) ;; *) ;; esac` instead of chained `[[ ]]` / `elif` when matching one variable against multiple string patterns
- Apply `${VAR:-}` defaults only to optional positional args (`"${2:-}"`) — required positionals are already validated by arg-count guards, so let `set -u` catch programming mistakes there. The existing rule about not defaulting well-known env vars still applies.
- Locals: `local` (or `local -r` for read-only) inside every function
- Functions: `snake_case`, defined with `function name() { ... }` (always use `function` keyword)
- Document positional parameters above each function with `# $1 = description` comments (use `# $@ = ...` for varargs)
- Default safely under `set -u`: use `"${VAR:-default}"` for vars that may legitimately be unset; do NOT add defaults for well-known env vars expected to always be present (`HOME`, `USER`, `SDKMAN_DIR`, `PATH`, etc.) — let `set -u` catch them if missing
- When parsing decimal strings that may have leading zeros (e.g. `date +%H` → `09`), use `10#` in arithmetic context (`$((10#${var}))`) or strip via `%-H`/`%-M` with GNU date — bash arithmetic treats `08`/`09` as invalid octal
- Force-decimal numbers from external commands before arithmetic comparison
- Tool availability: check with `command -v tool >/dev/null 2>&1`, never `which`
- Tempfiles: `tmp="$(mktemp)"` and `trap 'rm --force -- "${tmp}"' EXIT` for cleanup
- Heredocs: quote the terminator when no expansion wanted: `<<'EOF'`
- Use `printf '%s\n' "$x"` over `echo "$x"` when `$x` could start with `-` or contain backslashes
- Use `printf` (with explicit format string, including ANSI escapes like `'\033[0;32m%s\033[0m\n'` when colorizing) for any non-trivial output; never `echo -e`
- Use `--` before user-supplied paths in destructive commands (`rm --force --`, `mv --`)
- Iterate command output with `mapfile -t arr < <(cmd)`; never `for x in $(cmd)`
- Iterate positional parameters explicitly: `for x in "$@"; do ...; done`, not the implicit `for x; do ...; done` (clearer at a glance what is being iterated)
- Always pass `--no-run-if-empty` and an explicit `--max-args=N` to `xargs`
- Always use `read -r` (or `read -rp PROMPT`); never bare `read` (matches ShellCheck SC2162 — `-r` prevents backslash mangling)
- Scope `PATH` mutations inside a `( ... )` subshell so changes don't leak to the caller's environment
- For non-interactive `curl`, use: `curl --disable --fail --silent --location --show-error`. `--disable` skips `~/.curlrc` so behavior doesn't depend on the invoking user's config
- For non-interactive `wget`, use: `wget --no-config` (skips `~/.wgetrc` for the same reason)
- Network retry idiom for transient failures:

  ```bash
  tries=0
  until some_cmd; do
    (( tries += 1 ))
    if (( tries > 10 )); then
      die "Failed after 10 tries"
    fi
    sleep 15
  done
  ```
- Never parse `ls` output; use globs, `find`, or `fd`
- Avoid `eval`; if needed, justify with comment
- Use `source` instead of `.` when sourcing a file. The `source` keyword is more readable and unambiguous (a leading `.` is easy to overlook).
- When suppressing pipefail in one spot: explicit `|| true` with comment, not blanket disable
- All shell scripts must pass `shellcheck` before being considered complete
- Format shell scripts with: `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write <files>`
- Verify formatting (no in-place changes) with: `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --diff <files>`
- All shell scripts must pass the verify command above before being considered complete
- Use `# shellcheck disable=SCxxxx` only with a same-line comment justifying why
- Set strict IFS alongside the strict-mode pragma: `IFS=$'\n\t'` immediately after `set -Eeuo pipefail`
- New scripts must be created executable (`chmod +x`)
- Read values from `/etc/os-release` by sourcing it in a subshell, not by `grep`/`sed`/`awk`. The file is spec-defined as shell-sourceable, handles quoted values correctly, and exposes every field at once. Use a subshell so the sourced variables don't leak:

  ```bash
  # shellcheck disable=SC1091
  ( source '/etc/os-release' && printf '%s\n' "${ID}" )
  ```

- Use `find -printf '<fmt>'` for structured output (e.g. `find . -printf '%u:%g\n'`) instead of parsing default `find` output
- Use `stat --format='<fmt>'` for file metadata. For non-integer arithmetic, pipe through `bc` (bash `(( ))` is integer-only): `echo "scale=2; $(stat --format='%s' "${f}") / 1073741824" | bc`
- Use `set -E` and an `ERR` trap for stack-trace-style error reporting in non-trivial scripts:

  ```bash
  set -Eeuo pipefail
  trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR
  ```

- Pin minimum bash version when using bash 4+ features (associative arrays, `mapfile`, `${var^^}`, etc.):

  ```bash
  if (( BASH_VERSINFO[0] < 4 )); then
    echo 'bash 4+ required' >&2
    exit 1
  fi
  ```

- Always check `cd` results: `cd "${dir}" || exit 1`. Prefer scoped subshells over `pushd`/`popd`: `(cd "${dir}" && do_thing)`
- Standardize logging via helpers, all writing to stderr with timestamp + level prefix:

  ```bash
  log()      { printf '[%s] %-5s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" "$2" >&2; }
  log_info() { log INFO  "$*"; }
  log_warn() { log WARN  "$*"; }
  log_err()  { log ERROR "$*"; }
  ```

- SUID and SGID are forbidden on shell scripts. Use `sudo` to grant elevated access instead.
- All error messages must be written to stderr. The standard logging helpers above (`log`, `log_info`, `log_warn`, `log_err`) all write to stderr.
- Document non-trivial functions with a comment block above the definition: description, globals used or modified, arguments (using the `# $1 = description` style for each positional; `# $@ = ...` for varargs), outputs (stdout/stderr), and return value semantics. Library functions always require this; small internal helpers may be lighter.
- Comment tricky, non-obvious, or important code sections; explain *why*, not *what*.
- Use `TODO:` (all caps, no author identifier) to mark deferred work.
- Maximum line length is 80 characters. Wrap long strings via here-docs or embedded newlines. Long URLs and file paths may exceed when necessary.
- Pipeline formatting: a pipeline that fits on one line stays on one line. When wrapping, put one segment per line with the `|` at the start of the continuation line, indented 2 spaces from the opening command.
- Control flow opener: `; then` and `; do` on the same line as `if`/`while`/`for`. `else` on its own line. `fi`/`done` on their own line, aligned with the opener.
- `case` statement formatting: indent each alternative 2 spaces; multi-line alternatives put the pattern, the actions, and the closing `;;` on separate lines. Never use `;&` or `;;&` (fall-through) — write explicit cases instead.
- Single-character integer specials (`$?`, `$#`, `$$`, `$!`) are exempt from the "quote everything" rule — quoting is optional since they cannot contain whitespace or globs.
- Use `"$@"` to forward positional parameters; reach for `$*` only when you specifically need a single concatenated string.
- Use bash arrays for lists of elements or command-line flags to avoid quoting complications. Always expand with `"${array[@]}"` (quoted, `@` not `*`). Do not use arrays for complex data structures — bash arrays are not the right tool.
- Test for empty/non-empty strings with `[[ -z "$x" ]]` / `[[ -n "$x" ]]` rather than `[[ "$x" == "" ]]` / `[[ "$x" != "" ]]`.
- In `[[ ]]`, prefer `==` over `=` for equality.
- Never use `<` or `>` inside `[[ ]]` for numeric comparison (those are lexicographic). Use `(( a < b ))` or `[[ a -lt b ]]` instead.
- Use `./*` rather than `*` when feeding glob results to commands so filenames beginning with `-` aren't treated as options.
- Never pipe into `while`: the loop runs in a subshell, so any variable assignments inside are lost. Use process substitution (`while read -r ...; do ...; done < <(cmd)`) or read into an array first with `mapfile -t arr < <(cmd)`.
- Avoid bare `(( expr ))` as a standalone statement when the expression can evaluate to zero — under `set -e`, an exit status of 1 from the arithmetic kills the script. Use `(( expr )) || true` (with a same-line comment), `: $(( expr ))` for side effects only, or capture the value with `result=$(( expr ))`.
- Inside `$(( … ))`, omit the `${}` braces — the shell auto-resolves bare variable names: `$(( count + 1 ))` not `$(( ${count} + 1 ))`.
- Never define aliases in scripts. Use shell functions instead (aliases are inert in non-interactive shells anyway).
- Library functions should be namespaced with `::` (e.g. `files::exists`, `log::info`); internal/private helpers may keep plain `snake_case`.
- Name loop variables after the items being iterated: `for file in "${files[@]}"` not `for x in "${files[@]}"`.
- When using command substitution to assign a `local`, declare and assign on separate lines so the command's exit status is observable (`local` always returns 0 and masks the substitution's exit status):

  ```bash
  # wrong — masks cmd's exit status
  local result="$(cmd)"

  # right
  local result
  result="$(cmd)"
  ```

- Never append `|| exit 1` (or `|| exit N`) to a plain command-substitution assignment: `var="$(cmd)" || exit 1` is redundant under the mandatory `set -Eeuo pipefail` and short-circuits the `ERR` trap, which would otherwise print the failing line and command. Write `var="$(cmd)"` and let strict mode + the trap handle failure. For an explicit user-visible failure with a custom message, use `|| { echo "msg" >&2; exit 1; }` (or the project's `die`/`log_err` helper if one exists):

  ```bash
  # wrong — redundant, suppresses ERR trap context
  var="$(cmd)" || exit 1

  # right — let strict mode + ERR trap handle it
  var="$(cmd)"
  ```

  For `local`/`readonly`/`declare`/`export`, the split-declaration rule above applies — `local var="$(cmd)" || exit 1` never triggers because the builtin masks the substitution's exit status.
- File layout: only the shebang, strict-mode pragma, IFS, sourced libraries / `set` options, and constants appear before function definitions. All functions are grouped together below constants. No executable code is interleaved between function definitions.
- `main` function: top-level scripts containing one or more helper functions must wrap entry logic in `function main() { ... }`, defined as the last function. The final non-comment line of the script must be `main "$@"`. Scripts with zero helper functions may use straight-line code with no `main`. Library files (sourced helpers) are exempt. Keep arg-count guards and any `getopt` option parsing whose results modify `$@` at top-level above the `main` call — `main` should receive already-validated, already-parsed args.
- For pipelines whose per-stage exit codes matter, capture `PIPESTATUS` into a variable on the very next line — any subsequent command overwrites it:

  ```bash
  cmd_a | cmd_b | cmd_c
  status=( "${PIPESTATUS[@]}" )
  ```

- Prefer shell builtins, parameter expansion, and `=~` over external tools when they can do the job (`${var//pat/rep}` over `sed`, `${var%suffix}` over `cut`, `[[ "$s" =~ ^[0-9]+$ ]]` over `grep`). External commands are fine when the builtin form is unreadable.
- Consistency tiebreaker: when picking between equivalent options, match the existing patterns in surrounding code rather than introducing a third variant. But "we've always done it this way" is not a reason to keep an outdated style when the rule book has changed — apply current rules to new code.
