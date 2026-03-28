# Global Instructions

## Environment

- Java version management: SDKMAN (reads .sdkmanrc per project)

## Coding Conventions

- Prefer long CLI options over short flags (e.g., `--in-place` not `-i`, `--recursive` not `-r`)
- Write tests alongside implementation

## Maven

- If `./mvnw` exists in the project root, use it instead of `mvn`
- Prefer long options (e.g., `--batch-mode`, `--fail-at-end`)

## Shell Scripts

- Use `#!/usr/bin/env bash`
- Use `[[ ]]` over `[ ]`
- Use long options in commands (e.g., `grep --recursive` not `grep -r`)
- Quote all variable expansions: `"${var}"` not `$var`
- Use `${var}` brace syntax consistently

## Git

- Write concise commit messages in imperative mood
- Prefer feature branches over direct commits to main

## AWS CLI

- Prefer long options (e.g., `--region`, `--output`, `--query`)

## IntelliJ IDEA

- Do not suggest changes that conflict with checked-in `.idea` settings or `.editorconfig`
- Respect project-level code style and inspection configurations

## Docker

- Before running any Docker container, check IP forwarding: `sysctl net.ipv4.ip_forward`
- Expected output: `net.ipv4.ip_forward = 1`
- If the value is not 1, alert the user and do NOT run the container
