# Global Instructions

## Environment

- Java version management: SDKMAN
- Claude config dir: do NOT assume `~/.claude` exists. Always resolve via `$CLAUDE_CONFIG_DIR` env var (e.g., `$(printenv CLAUDE_CONFIG_DIR)` or `echo $CLAUDE_CONFIG_DIR`) to find the correct config directory

## Coding Conventions

- Prefer long CLI options over short flags (e.g., `--in-place` not `-i`, `--recursive` not `-r`)
- Write tests alongside implementation

## Maven

- If `./mvnw` exists in the project root, use it instead of `mvn`
- Prefer long options (e.g., `--batch-mode`, `--fail-at-end`)
- Maven exclusions must have a comment explaining why the dependency is excluded

## Maven Testing

- Run integration tests with: `./mvnw clean verify --fail-at-end 2>&1 | tee /tmp/test-output.log` (or `mvn` if no wrapper exists)
- Do NOT rerun tests just to find failures. Instead:
  1. Check target/failsafe-reports/ for structured XML results
  2. Or grep /tmp/test-output.log
- Only rerun tests after making a code change to fix a failure.

## Unit Testing

- Unit tests must only use the public API—never use reflection to access private fields or methods
- Never change a field or method modifier (e.g., `private` → `package-private`) for the sole purpose of making it testable
- If a feature cannot be tested through the public API, reconsider the design rather than exposing implementation details

## Long Multi-Step Tasks

- Before starting a long or multi-step process, identify all tools and permissions needed upfront
- Ask the user to approve all required permissions at once so the task can run unattended
- Do not begin execution until permission confirmations are in hand

## Response Style

- At the end of a response, add a brief summary of what you did

## Shell Scripts

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
- Functions: `snake_case`, defined with `name() { ... }` (no `function` keyword)
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

## Git

- Never force-add files that are listed in `.gitignore` (e.g., `git add --force`). If a file needs to be staged but is gitignored, stop and ask the user first.
- Branch naming: `type/description` in kebab-case 
  — Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`, `build`, `revert` (e.g., `feat/add-lz4-support`, `fix/s3-retry-timeout`, `chore/update-quarkus-bom`)
- Only run `./mvnw spotless:apply` before committing if the spotless plugin exists in the project's pom.xml (including inherited from parent poms)
- Commit messages follow the Angular convention: `type: subject`, imperative mood, 72-char subject line
  - Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`, `build`, `revert`
  - Append `!` after the type for breaking changes: `feat!: drop Java 11 support`
  - Optional body (after a blank line): explain *why*, not *what*
  - When generating a commit message, invoke the `/commit-commands:commit` skill

## AWS CLI

- Prefer long options (e.g., `--region`, `--output`, `--query`)

## IntelliJ IDEA

- Prefer to use the IntelliJ MCP server when available for code navigation, symbol lookup, and IDE operations
- Do not suggest changes that conflict with checked-in `.idea` settings or `.editorconfig`
- Respect project-level code style and inspection configurations

## Docker

- Before running any Docker container, check IP forwarding: `sysctl net.ipv4.ip_forward`
- Expected output: `net.ipv4.ip_forward = 1`
- If the value is not 1, alert the user and do NOT run the container

## Tool Availability

- Before using a command-line tool that is not guaranteed to be present, check whether it is installed
- If a required tool is missing, inform the user rather than silently failing or substituting a workaround
- Prefer faster modern alternatives when available (e.g., `rg` over `grep`, `fd` over `find`, `yq` over manual YAML parsing)

## Shell Commands
- When running Bash() tool commands, prefer `$VAR` over `${VAR}` unless the substitution syntax is necessary (e.g. `${VAR:-default}`, `${VAR%suffix}`). This does not apply to code Claude generates/edits — generated code should default to using `${}`.
- Any shell command that runs longer than 30 minutes must be killed. Use `timeout 30m` as a prefix for commands that could hang or run unexpectedly long (e.g., `timeout 30m ./mvnw pmd:check`). If a command is killed by the timeout, report it to the user rather than retrying silently.

## Documentation Paths
- Plans: `.claude/plans/`
- Specs: `.claude/specs/`

## settings.json
- When reading or writing any `settings.json` file (e.g., `.claude/settings.json`, `~/.claude/settings.json`), always keep all JSON keys sorted alphabetically at every nesting level. This applies both when creating the file from scratch and when modifying existing content — never leave keys in an unsorted order.
