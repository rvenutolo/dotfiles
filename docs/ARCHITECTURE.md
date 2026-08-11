# Architecture

How this repo turns one YAML file of facts into rendered config across hosts.
This document is the picture; [CLAUDE.md](../CLAUDE.md) is the ground truth for
conventions.

## Data flow: one source, many consumers

`.chezmoidata.yaml` holds the shared facts (hostnames, paths, git repo list,
age public key, weather city). Chezmoi loads it automatically and every
template reads from it — there is no second copy of any fact.

```mermaid
flowchart TD
    data[".chezmoidata.yaml"]
    config[".chezmoi.toml.tmpl"]
    profile["dot_config/profile.sh.tmpl"]
    tmpl["other *.tmpl files"]
    scripts[".chezmoiscripts/ run_* scripts"]

    data --> config
    data --> profile
    data --> tmpl
    data --> scripts

    config --> chezcfg["~/.config/chezmoi/chezmoi.toml (host facts, age identity)"]
    profile --> profsh["~/.config/profile.sh (export FOO=... shell env)"]
    tmpl --> targets["rendered dotfiles in $HOME"]
    scripts --> boot["bootstrap actions (packages, keys, validation)"]
```

Shell code never re-derives a shared fact: it sources the rendered
`~/.config/profile.sh`. Templates never use `{{ env "FOO" }}` for shared facts
(a pre-commit hook enforces this) because a fresh machine has no environment
yet — see [CLAUDE.md](../CLAUDE.md#standard-env-vars).

## Fresh-machine bootstrap

What happens on `chezmoi init --apply <repo>` on a blank host:

```mermaid
sequenceDiagram
    participant U as User
    participant C as chezmoi
    participant G as GitHub
    participant H as $HOME

    U->>C: chezmoi init --apply rvenutolo
    C->>G: clone source repo to ~/.local/share/chezmoi
    C->>C: render .chezmoi.toml.tmpl (bake host facts: is_personal, is_arch, ...)
    C->>H: write ~/.config/chezmoi/chezmoi.toml
    C->>C: run_before scripts (install packages, fetch+verify age keys, validate env)
    C->>H: apply source state (render templates, decrypt age files, fetch externals)
    C->>C: run_after scripts (set default editor, ...)
```

Host facts (`is_personal` / `is_work` / `is_server`, `is_arch` / `is_debian` /
`is_fedora`, ...) are **baked at init time** into the rendered
`chezmoi.toml`. Templates branch on them at apply time; a host must re-run
`chezmoi init` to pick up changes to fact derivation.

## State boundaries

```mermaid
flowchart LR
    subgraph src["Source state (git)"]
        s1["~/.local/share/chezmoi"]
    end
    subgraph tgt["Target state"]
        t1["$HOME dotfiles"]
        t2["~/.etc (staging for /etc)"]
    end
    subgraph ext["External/cache state"]
        e1["~/.cache/chezmoi (externals cache)"]
    end

    s1 -- "chezmoi apply" --> t1
    s1 -- "chezmoi apply" --> t2
    e1 -- "pinned externals" --> t1
```

- **Source state** is this repo. Filenames encode target metadata
  (`dot_`, `private_`, `exact_`, `encrypted_`, `symlink_`, `.tmpl`) — see
  [CLAUDE.md](../CLAUDE.md#chezmoi-source-state-conventions).
- **Target state** is what `chezmoi apply` materializes into `$HOME`. Files
  under `~/.etc/` are staging only: wiring into `/etc` is done manually by
  set-up scripts in the separate personal scripts repo, never by chezmoi.
- **External state**: third-party files/archives declared in
  `.chezmoiexternal.toml.tmpl`, pinned to commit SHAs and cached under
  `~/.cache/chezmoi/`. A SHA bump changes the URL, which busts the cache.
