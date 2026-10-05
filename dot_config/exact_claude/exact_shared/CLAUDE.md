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
- **Never use a real destructive command as test payload.** When a test needs *some* text to sit in the payload position — inside a heredoc whose termination is under test, in a string being parsed, in a fixture — use an inert marker (`echo PAYLOAD_RAN`, `touch /tmp/marker`) and assert on the marker. The whole point of such a test is that the parsing assumption might be wrong, and when it is wrong the payload runs. On 2026-08-26 a broad pattern-kill used as heredoc filler did exactly that and terminated the X session. Same signal, zero blast radius.
- The rule covers any payload with side effects, not just process kills: `rm`, `dd`, `shutdown`, `git push`, a request to a live endpoint. It also covers code written into a file and then executed — a `PreToolUse` guard only inspects the command string it is handed, so nothing inspects the inside of `bash script.sh`.

## Verifying Behavior Before Acting

- Before "fixing" code that you suspect is broken, verify the broken behavior empirically: run the function/command against the suspected input and observe the actual output. Code that *looks* broken in trace often works fine in practice (and vice versa).
- This applies during triage of test failures, debugging reported issues, and code review of suspect logic.
- The cost of a 30-second probe is far lower than the cost of a fix that "addresses" non-existent behavior.

## Fixing Findings

- A finding from a review, lint, audit or bug report names sites; it does not bound the problem. Before closing it, search the codebase for the same pattern and fix every match, not only the listed lines. A site list is what one sweep happened to find, and the sibling a few lines from a fixed site is the most common miss.
- If the class search turns up sites the fix should not absorb (a different file set, a different risk, a behavior change), report them instead of silently widening the change.

## Prioritizing Work Items

- When asked to order, rank or prioritize a set of items, "priority" means **implementation sequence**, not product value. The items are all going to be done and will ship together, so the question is which to do first, not which matters most to users.
- Order by engineering leverage: what makes the remaining work cheaper, faster or safer. Three factors, applied in this order when they conflict:
  1. **Unblocks other items.** A prerequisite, or something that makes other items simpler to write (a shared helper, a refactor, config plumbing) goes before the items that use it.
  2. **Speeds up the feedback loop.** Anything that makes every later iteration cheaper goes early: CI caching, faster tests, better lint or tooling. If a cache halves CI time, it is high priority regardless of how small the change is.
  3. **Retires risk or uncertainty.** The item most likely to fail, surprise, or change the design of the others goes as early as the first two allow, so the rest is planned on solid ground.
- "Quick wins" are not a factor. A small item is not early because it is small; it is early only if one of the three factors above applies.
- When the user explicitly asks for a value- or impact-based ranking, that overrides this default.

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

- Keep responses focused, brief, and concise. Keep disclaimers and caveats short, and spend most of the response on the main answer.
- When asked to explain something, give a high-level summary unless an in-depth explanation is specifically requested.
- At the end of a response, add a brief summary of what you did

### Attention Banners

- Any message that requires the user's response MUST begin with a banner line of exactly five emojis, on its own line, chosen by message type:
  - `❓❓❓❓❓` — a question or decision is needed
  - `🚧🚧🚧🚧🚧` — blocked; user action required (e.g., auth/login, missing prerequisite, denied permission)
  - `✅✅✅✅✅` — task complete; ready for review / next steps
- The banner is the first line of the final message of the turn.
- When using the AskUserQuestion tool, put the banner in the text immediately preceding the tool call (the dialog itself cannot carry it).
- Use banners only for messages awaiting the user's response — never on intermediate status updates.
- Do not use any other emojis elsewhere in the message.

## Git

- Never force-add files that are listed in `.gitignore` (e.g., `git add --force`). If a file needs to be staged but is gitignored, stop and ask the user first.
- Branch naming: `type/description` in kebab-case
  — Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`, `build`, `revert` (e.g., `feat/add-lz4-support`, `fix/s3-retry-timeout`, `chore/update-quarkus-bom`)
- Only run `./mvnw spotless:apply` before committing if the spotless plugin exists in the project's pom.xml (including inherited from parent poms)
- Commit messages follow the Angular convention: `type: subject`, imperative mood, 72-char subject line
  - Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`, `build`, `revert`
  - Append `!` after the type for breaking changes: `feat!: drop Java 11 support`
  - Optional body (after a blank line): explain *why*, not *what*

## GitHub

- The user's personal GitHub account (`rvenutolo`) is on the **Pro** plan. Treat Pro-tier features as available on their personal repos — public and private — and use them without first asking whether the plan allows it:
  - Branch protection rules, required reviewers, and CODEOWNERS on private repos
  - Draft pull requests and auto-merge on private repos
  - GitHub Pages and wikis on private repos
  - Repository insights (traffic, commits, code frequency, network, forks)
  - The larger GitHub Actions minutes and Packages storage allowances Pro grants for private repos
- Pro is an account-level plan, not a Copilot subscription — it does not imply GitHub Copilot access.
- Repos owned by an organization bill against that org's plan, not the user's Pro plan. Do not assume Pro-only features are available there.

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

## Destructive Commands

- A command that deletes or overwrites must name its targets in its own text, so it can be approved by reading that one command. This covers anything that removes or replaces data: `rm`, `rmdir`, `shred`, `truncate`, `dd`, `find -delete`, `mv` or `cp` onto an existing path, `>` onto an existing file, `git clean`, `git reset --hard`, `git checkout` / `git restore` of paths, `git branch -D`, recursive `chmod` / `chown`. The list is examples, not the boundary.
- Targets are literal paths. A target must not contain a variable assigned in the session (`rm "$s/$t"`), a command substitution (`rm "$(...)"`), or a loop variable (`for f in ...; do rm "$f"; done`), and must not arrive on a pipe (`... | xargs rm`, `find ... -exec rm`, `while read`).
- A glob is allowed only under a fully literal directory: `rm build/*.tmp`, never `rm "$dir"/*`. `find -delete` follows the same rule: literal start directory, literal predicates.
- Variables the environment sets and the session has not reassigned are allowed: `$HOME`, `$TMPDIR`, `$XDG_*`, `$CLAUDE_CONFIG_DIR`, `$DOTFILES_DIR`, `$PERSONAL_PROJECTS_DIR`. Write them as `${VAR:?}`, because an unset variable turns `rm --recursive "$VAR/"*` into `rm --recursive /*`.
- Do not `cd` and then delete by relative path in the same command; the directory the path resolves against is then as hidden as a variable. Use an absolute path, or a path relative to the directory the session is already in.
- When the targets are computed, use two commands. First a read-only command that prints them. Then the destructive command with those paths written out. If there are too many to write out, narrow to a literal directory or glob that matches exactly that set, or stop and ask.
- The rule covers code written to a file and then executed in the session (`bash script.sh`). It does not cover scripts written into a repo as deliverables; those follow the bash style rules.

## Writing Documentation
- Never hardcode absolute paths to the current repository in docs, skills, commands, rules, plans, specs, or any other artifact stored inside the repo. Use repo-root-relative paths (e.g., `.claude/rules/shell-scripts.md`, not `/home/<user>/Projects/Foo/.claude/rules/shell-scripts.md`). When the absolute path is genuinely needed at runtime, resolve it dynamically — e.g., `git rev-parse --show-toplevel` for the repo root, `$CLAUDE_CONFIG_DIR` for the Claude config dir, `$HOME` for the user's home — rather than embedding a literal path. Hardcoded paths break the moment the repo is cloned elsewhere or the user/machine changes.
- Never state a value that drifts with every edit in prose that nothing checks: a file's current line count, a count of files/functions/tests, or a `file.sh:NN` line reference. Cite code by function, heading or anchor. State the enforced limit ("under 200 lines, enforced by `.ci/check-fast-path-size`"), not today's value ("188 lines today"). Do not pin a figure to an event instead ("152 lines when #55 landed"): that is history, and docs and comments carry none.
- Documentation, code comments included, carries no historical information: how something used to work, when it was added, what a review found, which branch, commit or issue it came from. State what IS, in the present tense. Provenance belongs in commit messages and PR bodies.
- When a change alters what code does, update the comments and docs that describe that code in the same change. Read the comments above and inside what you edit, and search the repo's docs for the names you touched.
- When renaming or removing a file, function, flag, command or config key, search the whole repo for the old name, including docs, comments, scripts and config, and update or remove every reference in the same change.
- A comment explains why the code is the way it is: a constraint, a non-obvious choice, a trap. Do not write a comment that restates what the code does; it tells the reader nothing the code does not, and it goes stale when the code changes. A doc comment on a public API describes the contract, not the implementation.

## settings.json
- When reading or writing any `settings.json` file (e.g., `.claude/settings.json`, `~/.claude/settings.json`), always keep all JSON keys sorted alphabetically at every nesting level. This applies both when creating the file from scratch and when modifying existing content — never leave keys in an unsorted order.
- **Exception:** the chezmoi-managed shared Claude settings file (`~/.config/claude/shared/settings.json`, source `dot_config/exact_claude/exact_shared/settings.json.tmpl`). Its top-level keys must stay in Claude Code's own canonical write order, NOT alphabetical — Claude Code rewrites the file in that order, and an alphabetically sorted template makes `chezmoi apply` permanently prompt on a reorder-only diff. Never re-sort that file.
