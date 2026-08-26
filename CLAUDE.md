# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal dotfiles managed by [chezmoi](https://www.chezmoi.io/). The working tree at `${XDG_DATA_HOME}/chezmoi` (i.e. `~/.local/share/chezmoi`) is chezmoi's *source state*; running `chezmoi apply` materializes it into `${HOME}` (and a few system paths) on the target machine.

Diagrams of the data flow, bootstrap sequence, and state boundaries:
`docs/ARCHITECTURE.md`.

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

`is_arch` / `is_debian` / `is_fedora` are derived from
`.chezmoi.osRelease.id` + `.idLike`, so derivatives count (Ubuntu →
`is_debian`, EndeavourOS → `is_arch`). Like all `[data]` flags they are
baked at `chezmoi init` time — hosts must re-init to pick up changes.

`is_ci` is also derived (from the runtime `CI` env var, true when `chezmoi init` runs under GitHub Actions) and is used in `.chezmoiignore` to skip decrypt-dependent targets that CI has no age identity to render.

## Standard Env Vars

Canonical source of truth: `.chezmoidata.yaml` (hostnames, paths, git repo list, editor/pager/browser/terminal chains, age public key, weather city). Chezmoi loads this automatically; values are available in any `.tmpl` as `.hostnames.*`, `.paths.*`, `.editors.*`, `.pagers`, `.browsers`, `.terminals`, `.age.*`, `.weather.*`.

Shell consumers get the same values via `dot_config/profile.sh.tmpl`, which renders `export FOO=...` lines from `.chezmoidata.yaml` and lands at `${XDG_CONFIG_HOME}/profile.sh` on target. Both shell and chezmoi templates therefore share one source — no need to source profile.sh before `chezmoi init` on a fresh machine.

Paths in `.chezmoidata.yaml` are home-relative (no leading slash). Join with `.chezmoi.homeDir` when an absolute path is needed.

The `EDITOR` / `VISUAL` / `PAGER` / `BROWSER` / `TERMINAL` **preference
chains** live in `.chezmoidata.yaml` (`editors.text`, `editors.visual`,
`pagers`, `browsers`, `terminals`), ordered most-preferred first. `profile.sh.tmpl` renders them into the same runtime
probe chain as before (`command -v` / `__flatpak_installed` / `__real_cmd`), so
resolution still happens in the shell and a missing binary still degrades
gracefully — the *data* moved, the *behavior* did not. Templates that need only
the preferred binary read the head of a list: `{{ (index .editors.text 0).bin }}`
(`[edit]` in `.chezmoi.toml.tmpl`) and `{{ (index .pagers 0).bin }}`
(kitty `scrollback_pager`). The last entry of `editors.text` and `pagers` is the
unconditional fallback — assumed present, rendered without a probe.

Other conditional exports in `profile.sh.tmpl` — `MANPAGER`, `FILE_MANAGER`,
`TAILNET_IP`, `TAILNET_CIDR`, `TERM`, `SSH_ASKPASS`, etc. — remain shell-only.
They are derived from runtime state (`XDG_CURRENT_DESKTOP`, `tailscale status`,
another export) rather than from an ordered preference list, so there is nothing
for another template to reuse.

### Editors

- **micro is the primary terminal editor** (decision on #59): first in
  `editors.text` in `.chezmoidata.yaml`, which drives both the `EDITOR` chain
  rendered into `dot_config/profile.sh.tmpl` and `[edit]` in
  `.chezmoi.toml.tmpl`. Reorder the list to change the preference; do not edit
  the rendered chain.
- nano / hx / nvim / vim / vi are fallbacks for minimal or foreign machines.
  Their configs (`exact_nano/`, `exact_nvim/`) are deliberately minimal — do
  not invest in feature parity with micro. hx intentionally ships no config.
- `VISUAL` is a separate GUI chain (`editors.visual`: zed → lite-xl → kate,
  flatpak-aware — each entry probes `flatpak_id` before `bin`) that falls back
  to `$EDITOR`; `.chezmoiscripts/run_after_50-set-xdg-defaults.sh` reads it at
  runtime to set xdg-mime defaults. That script's `bin` → `.desktop` table is
  merged across all four roles (editor, browser, terminal, file manager) and is
  deliberately NOT data-driven: it maps a different fact, and covers apps
  (code, codium, lapce) that are in no chain. Each `bin` maps to a *prioritized
  list* of candidate ids — first one that exists on the host wins — because
  AM/appman and the distro ship duplicate ids for the same binary
  (`kitty.desktop` vs `kitty-AM.desktop`).

### Browsers and terminals

`browsers` and `terminals` are programChains like the editor ones, driving
`$BROWSER` / `$TERMINAL` in `profile.sh.tmpl` and the xdg-mime defaults set by
`.chezmoiscripts/run_after_50-set-xdg-defaults.sh`.

- **Every browser entry carries both a `flatpak_id` and a `bin`.**
  `profile.sh.tmpl` probes the flatpak first and falls back to the native
  binary, so flatpak is preferred *per app* while the app ordering still wins
  overall. Reorder the list to change preference; do not edit the rendered
  chain.
- **Most terminals are bin-only.** Only `wezterm` and `konsole` ship a flathub
  package; `ghostty`, `kitty`, `alacritty`, `gnome-terminal`, and `kgx` have
  none (verified 2026-08-25). Those entries are bin-only by necessity, not
  oversight — do not "fix" them by inventing a `flatpak_id`.
- **Neither chain has an unconditional final fallback** in the sense
  `editors.text` does. No browser is universally present, so `browsers` ends in
  `w3m` / `lynx`, which keep `$BROWSER` useful on `is_server` hosts but have no
  `.desktop` — the xdg-mime browser role simply skips with a WARN. `terminals`
  ends in `xterm`, which is near-universal on any X host.
- Browsers are probed with `__real_cmd`, never `command -v`: on a host with the
  personal scripts repo on `PATH`, most browser bins resolve to wrapper scripts
  that `__real_cmd` strips. `__real_cmd` also strips `/tmp/.mount_*/bin`,
  because an AppImage prepends its own mount dir to `PATH` for child processes
  and would otherwise make an app probe resolve to its own transient path.
- Adding an entry to either chain also needs a matching arm in
  `desktop_for_bin()` and a self-test case. A missing arm is not fatal — apply
  logs "no usable .desktop" and leaves mime defaults alone — but it is silent,
  so the test is what catches it.

`x-scheme-handler/mailto` is deliberately owned by no role; it is left at
whatever the user has set.

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
  Third-party entries are **pinned to commit SHAs** (supply-chain policy — the
  same one that governs `.github/workflows/` and `.pre-commit-config.yaml`):
  each carries a `# renovate:` comment that Renovate's regex manager uses to
  propose SHA bumps. Tracking a moving branch is allowed only with a justifying comment.
  Pinned URLs are immutable, so pinned entries use `refreshPeriod = '0'`; a SHA
  bump changes the URL, which busts the cache and refetches on the next apply.

  Those comments say `datasource=github-digest`, **not `git-refs`** — keep it
  that way when adding an entry. `git-refs` resolves the same branch head but
  reports no release timestamp, and the repo-wide `minimumReleaseAge` fails
  closed on a missing timestamp, so a `git-refs` entry would stop receiving
  PRs entirely rather than fail loudly. `github-digest` derives a timestamp
  from the commit date, which is what puts externals under the quarantine.
  Note its `depName` is the bare `owner/repo`, not the repo URL `git-refs`
  wanted.
- `.github/workflows/ci.yaml` — the lint + render CI workflow. The same
  supply-chain policy applies: every `uses:` is pinned to a 40-hex commit SHA
  with the version in a trailing comment (`@<sha> # v7.0.1`), because a tag is
  mutable and can be repointed by its owner. Renovate's `github-actions`
  manager reads that comment to propose SHA bumps; the `no-unpinned-actions`
  pre-commit hook stops a floating tag from creeping back.

  **Everything Renovate opens automerges** — `automerge: true` sits at the top
  level of `.github/renovate.json5` and covers all three managers and every
  update type. Two gates precede it: CI must be green (`ignoreTests` is left
  false, so Renovate will not merge a branch with failing checks), and the
  update must clear a repo-wide 7-day `minimumReleaseAge` quarantine. Merges
  land during the Saturday `schedule` window, not the moment a check goes
  green.

  This is a deliberate reversal of the earlier "external SHA bumps and
  pre-commit revs are reviewed by hand" policy. One class needed a replacement
  gate rather than just a decision: a `digest` bump on an already-pinned action
  means the upstream tag was repointed to different code at the same version —
  the mutable-tag substitution SHA pinning exists to catch.

  **`minimumReleaseAge` does not hold that class.** Renovate ages a `digest`
  update against the release timestamp of the *matched version*, and that
  version shipped months ago, so a repointed tag clears the 7-day window
  immediately. Renovate's docs say so outright: "Datasources whose timestamps
  reflect when the matched version was first released (such as `github-tags`
  for digest-pinned GitHub Actions) cannot detect re-published content." Do not
  reason about this from the quarantine's existence — it is the one update
  shape the quarantine is blind to. The gate that does hold it is
  `.dev/check-pin-digest-provenance.sh`, described under Scripts below.

  `minimumReleaseAge` is at the **top level** and `minimumReleaseAgeBehaviour`
  is left at its default `timestamp-required`, which fails closed. That is
  only safe because every datasource in use reports a release timestamp — the
  externals were moved off `git-refs` onto `github-digest` for exactly this
  reason. Introducing a timestamp-less datasource would silently stop its
  updates forever while remaining perfectly valid config.

  Externals also carry `internalChecksFilter: 'flexible'`, scoped to the
  `custom.regex` manager. They track a moving branch, so the datasource offers
  exactly one candidate release; the default `strict` filters a pending
  release and skips the PR "unless a non-pending version is available", and a
  single branch ref has no older version to fall back to. Every external whose
  upstream committed within the last week would go silent. `flexible` opens
  the PR immediately and leaves `renovate/stability-days` pending, so the
  update stays visible and hand-mergeable while only the automerge waits. The
  flapping that makes `flexible` a bad default elsewhere cannot occur here — a
  branch head only moves forward.

  The lint job does **not** use `pre-commit/action`. It runs `pre-commit`
  directly behind an `actions/cache` step whose `restore-keys` supplies a
  prefix fallback. That action keys its cache on python version + a hash of
  `.pre-commit-config.yaml` and offers no fallback, so any edit to that file is
  a total miss that rebuilds every hook environment (~2m). Renovate `rev:`
  bumps touch precisely that file, making it the most common PR here. Keep the
  `restore-keys` line and keep `pre-commit gc` — without the prune, a cache
  that is never invalidated grows an environment for every rev ever pinned.

  `shfmt` is installed from the pinned upstream release binary and verified
  against a `sha256` recorded in the workflow, not built with `go install`.
  Renovate can bump `SHFMT_VERSION` but cannot recompute that digest, so a
  version bump fails the step until the hash is regenerated by hand. That
  failure is intentional — do not drop the checksum to silence it.
- `.chezmoiignore` — paths in source state that should NOT be applied (`README.md`, `TODO`, `age.key.ENCRYPTED`)
- `.chezmoiscripts/` — host-bootstrap scripts (package install, key fetch). `run_onchange_before_00-install-packages.sh.tmpl` is the entry point that installs `age curl git jq openssh-client` via `apt` / `dnf` / `pacman`
- `exact_dot_etc/` — config files applied to `~/.etc/` that may be wired into `/etc`. Chezmoi does NOT do the /etc wiring: files are selectively symlinked or copied into `/etc` by set-up scripts in the personal scripts repo (`${PERSONAL_PROJECTS_DIR}/scripts`, e.g. `scripts/set_up/pacman/copy-pacman-conf-file`). `find-etc-symlinks` reports which files are currently linked where

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

Check for drift between source and target (exit code reflects status). Two
deliberate always-run scripts (`run_before_02-validate-env.sh.tmpl`, a
preflight that re-checks the baked distro flags, and
`run_after_50-set-xdg-defaults.sh`, which re-reads the runtime
`$BROWSER` / `$TERMINAL` / `$FILE_MANAGER` / `$VISUAL` on every apply) always
report as pending, so
bare `chezmoi verify` exits 1 even with zero real drift. Use
`--exclude=scripts` for a real drift signal (the justfile recipes already do):

```shell
chezmoi verify --exclude=scripts
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

age is the encryption backend. The recipient (public key) is pinned in `.chezmoidata.yaml` (`age.public_key`) and read by `.chezmoi.toml.tmpl` at init; the identity (private key) lives at `~/.keys/age.key` on each host. Encrypted files use the `encrypted_` prefix and (with two documented exceptions under `dot_config/exact_git/`) the `.age` suffix. Do not commit plaintext copies of `encrypted_*` files.

`private_dot_ssh/` holds SSH key material; entries are managed with `private_` (mode `0600`/`0700`) and, where applicable, `encrypted_` via age. Never add plaintext private keys here — encrypt first.

The get-keys bootstrap script verifies fetched ciphertexts against SHA-256
hashes pinned in `.chezmoidata.yaml` (`checksums:`); rotating keys requires
updating those hashes.

Rotation procedures (passphrase, age identity, SSH keypair) are documented
in `docs/age-rotation.md`.

## Scripts

Bootstrap scripts under `.chezmoiscripts/` and any new shell helpers must follow the bash style rules at `${PERSONAL_PROJECTS_DIR}/claude-rules/rules/generic.bash-style.md`: `#!/usr/bin/env bash`, `set -Eeuo pipefail` with `IFS=$'\n\t'`, long CLI options, `[[ ]]` over `[ ]`, quoted `${var}` expansions, `function name()` syntax, `readonly UPPER_SNAKE_CASE` constants, shdoc `# @description` / `# @arg` comments, etc. Read that file before writing or editing shell code — the list here is a summary, not the rule set.

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

### Pre-commit hooks

Install once per clone with `just hooks`. CI runs the identical config, so a
commit that passes locally passes the lint job.

`.pre-commit-config.yaml` currently configures twenty hooks. Grouped by
what they are for, rather than by the repo they come from:

- **Shell** — `shellcheck` and `shfmt`, plus `render-lint-sh-tmpl`, which
  renders `*.sh.tmpl` through chezmoi first because `{{ }}` is not valid bash.
- **Secrets and hygiene** — `gitleaks`, `end-of-file-fixer`,
  `trailing-whitespace`, `check-added-large-files`, `check-yaml`.
- **Spelling** — `typos`, whose two settings must not be removed (below).
- **Chezmoi data** — `check-jsonschema` validates `.chezmoidata.yaml` against
  `.chezmoidata.schema.json`; `check-paths-git-repos` requires every
  `git_repos` entry to have a matching `paths.<name>_dir`;
  `no-env-template-func` forbids `env "FOO"` in templates.
- **Supply chain** — `no-unpinned-actions`, `no-unpinned-precommit-revs` and
  `check-renovate-digests` keep actions, `rev:`s and externals on commit SHAs
  with a `# renovate:` comment.
- **CI plumbing** — `actionlint` and `renovate-config-validator` (see below;
  nothing else validates either file).
- **Local test suites** — `pin-digest-provenance-test` runs
  `.dev/check-pin-digest-provenance.test.sh`, `pgrep-hook-self-test` runs
  the `--self-test` table built into
  `dot_config/exact_claude/exact_shared/hooks/executable_block-pgrep-self-match.sh`,
  and `xdg-defaults-self-test` runs the `--self-test` table built into
  `.chezmoiscripts/run_after_50-set-xdg-defaults.sh`.
  These are the repo's own tests, not third-party linters; a change to any of
  those scripts that breaks its suite fails the commit.

  The pgrep hook denies four kinds — `kill`, `loop`, `task-poll` (a
  loop on a harness `…/tasks/<id>.output` file), and `repeat`
  (the third probe of one target in 300 s). `repeat` is the hook's only
  stateful rule: one file per session at
  `${XDG_RUNTIME_DIR}/block-pgrep-self-match/<session_id>` (override with
  `BLOCK_PGREP_STATE_DIR`), touched only by commands that carry a probe
  key, pruned on every write, and every state failure allows. Its suite
  (`run_repeat_tests`) runs against a throwaway dir inside `--self-test`.

Keep this list in step with the file. It has drifted before — it named seven
hooks while the config had nineteen — and a hook nobody knows about is one
nobody maintains.

The `typos` hook carries two settings that must not be removed:

- **`args: []`** overrides the upstream default of `[--write-changes]`, which
  rewrites files in place. That default was trialled against this repo and
  renamed `extra-substituters` to `extra-substitutes` in two Nix configs,
  rewrote a real domain in a `WebFetch` permission, renamed the Siduction
  distro in neofetch's table, and inserted a character into age ciphertext.
- **`exclude: '\.age$'`** — the `files.extend-exclude` glob in `.typos.toml`
  applies only while typos *walks* a tree, and pre-commit passes filenames
  explicitly, which bypasses the walk. The glob stays as the backstop for
  direct CLI runs; the hook-level exclude is what actually takes effect.

Use hook id `typos` (a prebuilt binary), never `typos-src` (compiles from
source). Word exceptions live in `.typos.toml`, named with a leading dot so
chezmoi ignores it — `_typos.toml` is read by the same tool but would be
applied to the target as `~/_typos.toml`.

**Trialling a hook with `pre-commit try-repo` is not read-only.** It runs the
hook with its upstream `args:`, so a fixer hook fixes. Trial on a clean tree
you are ready to `git restore`, or invoke the underlying tool directly.

### Scheduled link checking

`.github/workflows/link-check.yaml` runs lychee weekly (Mondays 06:00 UTC) and
on `workflow_dispatch`, over the markdown files, `.pre-commit-config.yaml`, and
`.chezmoiexternal.toml.tmpl`. **Keep it off the PR path.** It needs the network
and fails for reasons unrelated to the commit under test, which would make an
otherwise hermetic CI run flaky; link rot also arrives without a commit, so a
schedule is the fitting trigger. It authenticates with the job's `GITHUB_TOKEN`
because most of the URLs are on github.com, which rate-limits anonymous
requests hard enough to redden the run by itself.

### Pin digest provenance

`.dev/check-pin-digest-provenance.sh` is the gate on Renovate's automerge path.
It diffs every GitHub Actions pin (`uses: owner/repo@<sha> # <version>`) and
every pre-commit `rev:` (`<sha>  # frozen: <version>`) against the PR's base ref
and fails any SHA that moved while its version label did not — a repointed
released tag, which no legitimate release produces. It exists because
`minimumReleaseAge` is blind to exactly that shape (see the `automerge` note
above); with every update type automerging, this is the only automated check
standing between a repointed tag and `main`.

Facts worth keeping straight before editing it:

- **It runs in CI only**, as the `pin-provenance` job, gated on
  `github.event_name == 'pull_request'`. The check is a diff against a base
  ref, so on a local commit or a push to main the base *is* the commit and it
  would pass trivially — coverage that looks real and is not. The job needs its
  own `git fetch` step; `actions/checkout` leaves no `refs/remotes/origin/*`.
- The pre-commit hook `pin-digest-provenance-test` runs the **test suite**
  (`.dev/check-pin-digest-provenance.test.sh`, 18 cases), not the gate.
- **Keying is on `(pin identity, version)`, deliberately not on the file.** A
  workflow renamed in the same PR that repoints a pin must still be caught
  rather than read as an add plus a remove. There is a case for this.
- **It is offline by design** — no GitHub API, no token. The cost is one false
  positive: a pin naming an annotated tag *object* versus one naming the commit
  that tag points at are the same release one dereference apart but compare as
  a repoint. Renovate always writes the dereferenced commit, so only a hand-edit
  can produce it. Loud false positive, not a silent gap.
- **Exit 2 is not exit 1.** A pin shape it cannot parse, an unresolvable base
  ref, or an unreadable base file exits 2 (could not run), never 0. A gate that
  cannot read the base must never report OK.
- Floating-major labels (`# v7`) retarget legitimately, and telling that from a
  repoint needs an upstream reachability probe this offline gate does not do, so
  a moved SHA under one is reported rather than guessed at. Nothing here uses
  that shape; `CLAUDE.md` requires exact `# vX.Y.Z` labels.

Several test cases exist because a mutation of the checker slipped past an
earlier version of the suite — notably the git-ref base path (`git ls-tree` /
`git show`), which the directory-fixture cases do not reach even though it is
the path CI actually uses. Keep those cases when refactoring.

Two hooks lint the CI plumbing itself:

- **actionlint** — validates `.github/workflows/*.yaml` (schema, expressions,
  matrix/`needs` wiring) and shellchecks the embedded `run:` scripts, which
  the `shellcheck` hook above cannot reach because it matches `\.(sh|bash)$`.
  The embedded-script pass runs **only when `shellcheck` is on `PATH`** —
  actionlint skips it silently and still exits 0 otherwise, so the CI lint job
  asserts `shellcheck --version` before running pre-commit. Keep that step.
- **renovate-config-validator** — validates `.github/renovate.json5`. Nothing
  else does: a typo in a manager name or a broken `matchStrings` regex fails
  no build, it just makes Renovate stop proposing those updates while the
  pinned externals quietly go stale.

`rev:` bumps automerge along with everything else (see the `automerge` note
under `.github/workflows/ci.yaml` above) once CI is green and the 7-day
quarantine has passed. `renovatebot/pre-commit-hooks` cuts a release for every
Renovate release — several per week — and no longer needs the narrow
per-repo automerge rule it once had.

Every `rev:` in `.pre-commit-config.yaml` is a **40-hex commit SHA** with the
version in a trailing `# frozen:` comment, under the same supply-chain policy
as GitHub Actions and externals — and for a stronger reason: hooks execute on
the developer's machine at commit time with access to `~/.keys` and `~/.ssh`,
where an action only ever runs in a disposable runner. The
`no-unpinned-precommit-revs` hook stops a tag from creeping back.

**Do not maintain those revs with `pre-commit autoupdate --freeze`.** It picks
each repo's latest tag via `git describe` against the default branch, so a
release tagged off-mainline is invisible to it — as of 2026-08 that silently
*downgrades* gitleaks from v8.30.1 (a lightweight tag on a commit not
reachable from `main`) to v8.30.0, four months older. Renovate owns these
bumps; to set one by hand, resolve the tag with
`git ls-remote <repo> refs/tags/<tag> 'refs/tags/<tag>^{}'` and take the
dereferenced (`^{}`) SHA when the tag is annotated.

## When Adding Files

1. Pick the correct prefix chain for the target path/mode/semantics.
2. If the content varies by host, make it a `.tmpl` and gate on `is_personal` / `is_work` / `is_server` / etc.
3. If it's a secret, use `encrypted_` (and `private_` if mode matters).
4. If it should not be applied (docs, scratch), add it to `.chezmoiignore`.
5. Run `chezmoi diff` before `chezmoi apply` to confirm the rendered target matches intent.
