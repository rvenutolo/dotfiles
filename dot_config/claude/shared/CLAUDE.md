# Global Instructions

## Environment

- Java version management: SDKMAN (reads .sdkmanrc per project)

## Coding Conventions

- Prefer long CLI options over short flags (e.g., `--in-place` not `-i`, `--recursive` not `-r`)
- Write tests alongside implementation

## Shell Scripts

- Use `#!/usr/bin/env bash`
- Use `[[ ]]` over `[ ]`
- Use long options in commands (e.g., `grep --recursive` not `grep -r`)
- Quote all variable expansions: `"${var}"` not `$var`
- Use `${var}` brace syntax consistently

## Git

- Write concise commit messages in imperative mood
- Prefer feature branches over direct commits to main

## Docker

- Before running any Docker container, check IP forwarding: `sysctl net.ipv4.ip_forward`
- Expected output: `net.ipv4.ip_forward = 1`
- If the value is not 1, alert the user and do NOT run the container
