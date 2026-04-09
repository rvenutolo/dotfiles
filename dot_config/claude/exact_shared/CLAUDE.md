# Global Instructions

## Environment

- Java version management: SDKMAN
- SDKMAN auto-switching does not apply to non-interactive shells. If a Java version mismatch is suspected, source SDKMAN and activate the project's `.sdkmanrc` version before running any Java/Maven commands:
  `source "$SDKMAN_DIR/bin/sdkman-init.sh" && sdk env`

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

## Response Style

- At the end of a response, add a brief summary of what you did

## Shell Scripts

- Use `#!/usr/bin/env bash`
- Use `set -euo pipefail`
- Use `[[ ]]` over `[ ]`
- Use long options in commands (e.g., `cut --delimiter` not `cut -d`)
- Quote all variable expansions: `"${var}"` not `$var`
- Use `${var}` brace syntax consistently

## Git

- Branch naming: `type/description` in kebab-case 
  — Allowed types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`, `style`, `build`, `revert` (e.g., `feat/add-lz4-support`, `fix/s3-retry-timeout`, `chore/update-quarkus-bom`)
- Run `./mvnw spotless:apply` before committing
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
When running Bash() tool commands, prefer `$VAR` over `${VAR}` unless the substitution syntax is necessary (e.g. `${VAR:-default}`, `${VAR%suffix}`). This does not apply to code Claude generates/edits — generated code should default to using `${}`.

## Superpowers Documentation Paths
- Save Superpowers plans to: `.claude/superpowers/plans/`
- Save Superpowers specs to: `.claude/superpowers/specs/`
