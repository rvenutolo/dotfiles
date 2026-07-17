# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/). The working tree at `${XDG_DATA_HOME}/chezmoi` (i.e. `~/.local/share/chezmoi`) is chezmoi's *source state*; running `chezmoi apply` materializes it into `${HOME}` (and a few system paths) on the target machine.

## Access Path

User normally accesses this repo via `${DOTFILES_DIR}`, which is a symlink to `${XDG_DATA_HOME}/chezmoi`. Both paths resolve to the same source tree — use either. Prefer `${DOTFILES_DIR}` in user-facing references; resolve to the real path only when a tool requires a canonical location.

## Chezmoi Source-State Conventions

Filenames in this repo are not literal paths — they encode target-state metadata. Understand the prefixes before editing or adding files:

- `dot_foo` → `~/.foo` (leading dot in target)
- `private_foo` → mode `0600` (or `0700` for dirs)
- `exact_foo/` → directory contents managed exactly: chezmoi removes unmanaged entries on apply. Applies only to files directly inside the dir, not recursively — subdirectories need their own `exact_` prefix to get the same treatment
- `symlink_foo` → target is a symlink; file contents are the link target
- `encrypted_foo` → decrypted on apply via age (key at `~/.keys/age.key`)
- `*.tmpl` → Go-template rendered with chezmoi data (host facts, `is_personal`, `is_work`, etc.)
- `run_once_before_NN-*.sh` / `run_once_after_NN-*.sh` → chezmoi script hooks, ordered by `NN`. Re-run only when script content hash changes — not on every apply. Sibling forms: `run_onchange_*` (re-run when content changes, no once-guard), `run_*` (every apply)
- `remove_dot_foo` → ensures `~/.foo` does NOT exist on target

Prefixes compose: `private_dot_ssh`, `encrypted_private_profile-local-personal.sh.age`, `symlink_dot_profile-local.tmpl`, etc. When renaming or moving a managed file, the prefix(es) must be preserved or the target-state semantics change.

## Host-Specific Templating

`.chezmoi.toml.tmpl` derives boolean facts from `chezmoi.hostname`:

- `redstar` / `bluestar` → `is_personal = true`
- `silverstar` → `is_work = true`
- anything else → `is_server = true`

`is_desktop` / `is_laptop` / `is_wtf` / `is_io` are also exposed. Templates in this repo gate config blocks on these flags — do not hardcode hostnames in new content; reuse the booleans from `.chezmoi.toml.tmpl` data.

## Standard Env Vars

Canonical source of truth: `.chezmoidata.yaml` (hostnames, paths, age public key, weather city). Chezmoi loads this automatically; values are available in any `.tmpl` as `.hostnames.*`, `.paths.*`, `.age.*`, `.weather.*`.

Shell consumers get the same values via `dot_config/profile.sh.tmpl`, which renders `export FOO=...` lines from `.chezmoidata.yaml` and lands at `${XDG_CONFIG_HOME}/profile.sh` on target. Both shell and chezmoi templates therefore share one source — no need to source profile.sh before `chezmoi init` on a fresh machine.

Paths in `.chezmoidata.yaml` are home-relative (no leading slash). Join with `.chezmoi.homeDir` when an absolute path is needed.

Conditional exports in `profile.sh.tmpl` — `EDITOR`, `VISUAL`, `PAGER`, `MANPAGER`, `FILE_MANAGER`, `TAILNET_IP`, `TAILNET_CIDR`, `TERM`, etc. — that are gated on `__executable_exists` / `case` / runtime probes are not in chezmoidata; they're shell-only and not meant for cross-file reuse.

### Usage policy

When a config file or script references a path or hostname covered by these vars, prefer (in order):

1. **Literal env var inside the file** (`${XDG_CONFIG_HOME}/foo/bar`) — only if the consuming tool/parser expands env vars in that field. Verify with the tool's docs before using.
2. **Chezmoi template** — rename file to `.tmpl` and use `{{ .chezmoi.homeDir }}/{{ .paths.xdg_config_home }}/foo/bar` (or `.hostnames.*`, `.age.*`, etc.). Chezmoi resolves at apply time; the rendered file contains a literal absolute path.
3. **Hardcoded path** — only when neither option above is viable.

Never use `{{ env "FOO" }}` for these vars — `env` reads the user's *current* shell, which may not have profile.sh sourced (e.g. fresh-machine `chezmoi init`). Use chezmoidata instead.

If a new shared fact is needed, add it to `.chezmoidata.yaml` and (if shell needs it) `profile.sh.tmpl` — do not introduce one without the other.

## Template Data

Beyond the custom `is_*` booleans, `.tmpl` files have access to chezmoi's built-in template data and funcs:

- `.chezmoi.hostname` — short hostname
- `.chezmoi.os` — `linux`, `darwin`, etc.
- `.chezmoi.arch` — `amd64`, `arm64`, etc.
- `.chezmoi.homeDir` — target user's `${HOME}`
- `.chezmoi.sourceDir` — absolute path to this repo's source state
- `.chezmoi.username` — target user
- `env "FOO"` — read env var at render time
- `output "cmd" "arg"...` — capture command stdout

Full reference: https://www.chezmoi.io/reference/templates/variables/

## Key Files

- `.chezmoi.toml.tmpl` — config rendered into `~/.config/chezmoi/chezmoi.toml` on init; defines host facts and age encryption identity/recipient
- `.chezmoiexternal.toml.tmpl` — external resources (files / git-repos / archives) chezmoi fetches and places under target paths; `refreshPeriod` controls TTL. Cache lives at `~/.cache/chezmoi/`; `chezmoi apply --refresh-externals` forces refetch
- `.chezmoiignore` — paths in source state that should NOT be applied (`README.md`, `TODO`, `age.key.ENCRYPTED`)
- `.chezmoiscripts/` — host-bootstrap scripts (package install, key fetch, post-apply URL rewrite). `run_once_before_00-install-packages.sh` is the entry point that installs `age curl git jq openssh-client` via `apt` / `dnf` / `pacman`
- `exact_dot_etc/` — config files that may be symlinked into `/etc`; `find-etc-symlinks` reports the link sites

## Editing Workflow

Never edit target files (e.g. `~/.bashrc`) directly with a text editor — next `chezmoi apply` overwrites the hand-edit. Two correct paths:

- `chezmoi edit <target>` — opens the source file (resolves prefixes/template for you), reapplies on save.
- Edit the source path under `${DOTFILES_DIR}` directly, then `chezmoi apply`.

If a target was already hand-edited and the change should be kept: `chezmoi re-add <target>` pulls live target content back into source state. Use `chezmoi diff` first to see what would be captured.

## Common Commands

Apply changes to `${HOME}`:

```shell
chezmoi apply
```

Diff source state against target:

```shell
chezmoi diff
```

Re-edit a managed file (opens the source, not the target):

```shell
chezmoi edit ~/.bashrc
```

Add a new managed file from the live target:

```shell
chezmoi add ~/.config/foo/bar.conf
```

Pull from git remote and apply in one step:

```shell
chezmoi update
```

Check for drift between source and target (exit code reflects status):

```shell
chezmoi verify
```

Sanity-check environment (binaries, config, encryption, externals):

```shell
chezmoi doctor
```

Test a template render without applying:

```shell
chezmoi execute-template < some-file.tmpl
```

Reset chezmoi state (per README):

```shell
rm -rf ~/.config/chezmoi ~/.local/share/chezmoi
```

## Encryption

age is the encryption backend. Recipient and identity are pinned in `.chezmoi.toml.tmpl`. Encrypted files use the `encrypted_` prefix and `.age` suffix. Do not commit plaintext copies of `encrypted_*` files.

`private_dot_ssh/` holds SSH key material; entries are managed with `private_` (mode `0600`/`0700`) and, where applicable, `encrypted_` via age. Never add plaintext private keys here — encrypt first.

## Scripts

Bootstrap scripts under `.chezmoiscripts/` and any new shell helpers must follow the bash style rules at `${PERSONAL_PROJECTS_DIR}/claude-rules/generic.bash-style.md`: `#!/usr/bin/env bash`, `set -Eeuo pipefail` with `IFS=$'\n\t'`, long CLI options, `[[ ]]` over `[ ]`, quoted `${var}` expansions, `function name()` syntax, `readonly UPPER_SNAKE_CASE` constants, shdoc `# @description` / `# @arg` comments, etc. Read that file before writing or editing shell code — the list here is a summary, not the rule set.

The rules apply to any file whose contents are bash, regardless of extension — including chezmoi `run_*` / `modify_*` scripts, which carry no `.sh` suffix and so fall outside the rules file's own `**/*.sh` path globs.

Every script in this repo follows the current rules. There is no grandfathering: when the rule set changes, existing scripts are updated to match rather than left as-is.

Scripts must pass both:

```shell
shellcheck <files>
shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --diff <files>
```

`.tmpl` scripts must be rendered before linting — `{{ }}` is not valid bash:

```shell
chezmoi execute-template < <script>.tmpl | shellcheck -
```

### Sourced bash files are partially exempt

`dot_config/exact_bash/*.bash` are sourced into the shell (`~/.bashrc` → `.config/bash/bashrc.bash`), not executed. Per the rules file's scope section they are exempt from the execution-shaped rules — `set -Eeuo pipefail`, `IFS=$'\n\t'`, the `ERR` trap, `main "$@"`, the file-layout rule, and the executable bit. Applying those would break the interactive shell: `set -e` closes the terminal on any non-zero command, and `IFS` alters word splitting session-wide.

All other rules — quoting, `${var}` braces, `function` keyword, `[[ ]]`, long options, shdoc comments, `shellcheck`, `shfmt` — still apply to them.

## When Adding Files

1. Pick the correct prefix chain for the target path/mode/semantics.
2. If the content varies by host, make it a `.tmpl` and gate on `is_personal` / `is_work` / `is_server` / etc.
3. If it's a secret, use `encrypted_` (and `private_` if mode matters).
4. If it should not be applied (docs, scratch), add it to `.chezmoiignore`.
5. Run `chezmoi diff` before `chezmoi apply` to confirm the rendered target matches intent.
