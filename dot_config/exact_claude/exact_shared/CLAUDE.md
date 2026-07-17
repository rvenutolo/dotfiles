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

## Testing Philosophy

- Tests are **specification-driven**, not characterization-driven. Each test encodes what the function *should* do — derived from its name, doc comment, and reasonable invariants — not what the current code happens to do. Characterization tests lock in bugs; spec-driven tests find them.
- When a test fails, classify the failure into one of three buckets and act accordingly:
  - **Genuine bug** in the function under test → fix the function. Default action.
  - **Spec ambiguity** (behavior is reasonable but undocumented; multiple plausible interpretations) → escalate to the user, get an explicit decision, then update whichever side (function or test) needs alignment.
  - **Test bug** (assertion was wrong) → fix the test. Should be rare if tests are derived from the spec.
- Default heavily toward the "genuine bug" interpretation. The whole point of spec-driven tests is to surface real defects in shipped code.
- Separate `fix:` commits from the `test:` commit that surfaced the bug, even if they land back-to-back. The `fix:` commit message should reference the surfacing test by name. Bundling fixes into test commits hides defect history from `git log --grep='^fix:'` and from blame tooling.

## Verifying Behavior Before Acting

- Before "fixing" code that you suspect is broken, verify the broken behavior empirically: run the function/command against the suspected input and observe the actual output. Code that *looks* broken in trace often works fine in practice (and vice versa).
- This applies during triage of test failures, debugging reported issues, and code review of suspect logic.
- The cost of a 30-second probe is far lower than the cost of a fix that "addresses" non-existent behavior.

## Long Multi-Step Tasks

- Before starting a long or multi-step process, identify all tools and permissions needed upfront
- Ask the user to approve all required permissions at once so the task can run unattended
- Do not begin execution until permission confirmations are in hand

## Unattended Execution / Pre-Answer Halt Questions

- Before kicking off any work that may run unattended (overnight, while user is away, or in a long subagent-driven loop), identify every likely "halt point" the work could hit and pre-answer each one with the user in a single batched message before execution begins. A halt point is anything where the executor would otherwise stop and ask: design ambiguities, multiple plausible fixes, behavior decisions where the spec is silent, edge cases with no clearly correct answer, sed/regex/parsing semantics that could go multiple ways, etc.
- Lead each halt question with a recommended option and a one-line rationale, so the user can confirm with a single response (`A`, `approved`, etc.) rather than typing out reasoning.
- Bake user-confirmed answers into the plan as "controller resolved with user" notes that subagent prompts cite verbatim. Do not let an executor rediscover an already-answered question.
- For unforeseen low-stakes ambiguities discovered mid-execution: pick the most conservative interpretation, leave a `# TODO:` comment, and surface the decision in the morning summary. Halt as `BLOCKED` only for ambiguities with security or invariant implications.
- This rule applies to any unattended-execution AI workflow — not just specific tools or domains. The cost of front-loading design decisions is paid once; the cost of an unanswered halt question paged at 3am is paid every time.
- Verify delegated-work state independently before trusting reports. Subagent / agent / tool output occasionally truncates mid-report, or describes *intent* rather than verified state. After any delegated task that should have produced a code/file change, check the resulting state directly — `git status`, `git log`, re-run the verification command, read the file — before marking the task complete or moving to the next step.

## Response Style

- At the end of a response, add a brief summary of what you did

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

## Writing Documentation
- Never hardcode absolute paths to the current repository in docs, skills, commands, rules, plans, specs, or any other artifact stored inside the repo. Use repo-root-relative paths (e.g., `.claude/rules/shell-scripts.md`, not `/home/<user>/Projects/Foo/.claude/rules/shell-scripts.md`). When the absolute path is genuinely needed at runtime, resolve it dynamically — e.g., `git rev-parse --show-toplevel` for the repo root, `$CLAUDE_CONFIG_DIR` for the Claude config dir, `$HOME` for the user's home — rather than embedding a literal path. Hardcoded paths break the moment the repo is cloned elsewhere or the user/machine changes.

## settings.json
- When reading or writing any `settings.json` file (e.g., `.claude/settings.json`, `~/.claude/settings.json`), always keep all JSON keys sorted alphabetically at every nesting level. This applies both when creating the file from scratch and when modifying existing content — never leave keys in an unsorted order.
- **Exception:** the chezmoi-managed shared Claude settings file (`~/.config/claude/shared/settings.json`, source `dot_config/exact_claude/exact_shared/settings.json.tmpl`). Its top-level keys must stay in Claude Code's own canonical write order, NOT alphabetical — Claude Code rewrites the file in that order, and an alphabetically sorted template makes `chezmoi apply` permanently prompt on a reorder-only diff. Never re-sort that file.
