- Use `#!/usr/bin/env bash`
- Use `set -euo pipefail`
- Use `[[ ]]` over `[ ]`
- Use `(( ))` for arithmetic; never `let` or `expr`
- Use long options in commands (e.g., `cut --delimiter` not `cut -d`)
- Quote all variable expansions: `"${var}"` not `$var`
- Use `${var}` brace syntax consistently
- Quote command substitutions: `"$(cmd)"`
- Use `$(...)` not backticks
- Indent with 2 spaces; never tabs
- Constants and config: `readonly` and `UPPER_SNAKE_CASE` at top of script
- Locals: `local` (or `local -r` for read-only) inside every function
- Functions: `snake_case`, defined with `function name() { ... }` (always use `function` keyword)
- Default safely under `set -u`: `"${VAR:-default}"` for any externally-provided var
- When parsing decimal strings that may have leading zeros (e.g. `date +%H` → `09`), use `10#` in arithmetic context (`$((10#${var}))`) or strip via `%-H`/`%-M` with GNU date — bash arithmetic treats `08`/`09` as invalid octal
- Force-decimal numbers from external commands before arithmetic comparison
- Tool availability: check with `command -v tool >/dev/null 2>&1`, never `which`
- Tempfiles: `tmp="$(mktemp)"` and `trap 'rm --force -- "${tmp}"' EXIT` for cleanup
- Heredocs: quote the terminator when no expansion wanted: `<<'EOF'`
- Use `printf '%s\n' "$x"` over `echo "$x"` when `$x` could start with `-` or contain backslashes
- Use `--` before user-supplied paths in destructive commands (`rm --force --`, `mv --`)
- Iterate command output with `mapfile -t arr < <(cmd)`; never `for x in $(cmd)`
- Never parse `ls` output; use globs, `find`, or `fd`
- Avoid `eval`; if needed, justify with comment
- When suppressing pipefail in one spot: explicit `|| true` with comment, not blanket disable
- All shell scripts must pass `shellcheck` before being considered complete
- Format shell scripts with: `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write <files>`
- Verify formatting (no in-place changes) with: `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --diff <files>`
- All shell scripts must pass the verify command above before being considered complete
- Use `# shellcheck disable=SCxxxx` only with a same-line comment justifying why
- Set strict IFS alongside the strict-mode pragma: `IFS=$'\n\t'` immediately after `set -euo pipefail`
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
