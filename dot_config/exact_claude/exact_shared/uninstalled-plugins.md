# Uninstalled Plugins

Plugins deliberately **not installed** in either Claude profile
(`${XDG_CONFIG_HOME}/claude/{personal,work}`), with the reason for each.

`settings.json` is the only plugin declaration chezmoi carries to a new machine, so a plugin
that belongs here is simply absent from `enabledPlugins`. Nothing re-installs it; nothing needs
to disable it.

## Why uninstall rather than disable

This policy started as a workaround. Setting a plugin to `false` in `enabledPlugins` used to
leave it half-alive:

- **Skills still appeared in the system prompt**, consuming context window tokens even when the
  plugin was disabled —
  [#34940](https://github.com/anthropics/claude-code/issues/34940) (closed 2026-03-20),
  [#40789](https://github.com/anthropics/claude-code/issues/40789) (closed 2026-05-05).
- **`SessionStart` and `UserPromptSubmit` hooks still fired**, injecting context on every
  session and every message. A plugin with a large `SessionStart` hook (e.g. a 15KB knowledge
  graph) could consume 15–20% of the context window before the user said anything —
  [#35713](https://github.com/anthropics/claude-code/issues/35713) (closed 2026-03-21).

All three are fixed: a disabled plugin now stays quiet. Uninstalling remains the policy anyway,
for reasons the bugs never covered:

- **Disk.** Every installed plugin is a git checkout under `plugins/cache/`, duplicated per
  profile, and old versions accumulate as separate directories. `caveman` alone held 66M in the
  personal profile and 42M in the work profile across several stale version checkouts.
- **Update cost.** `claude-plugins-update` (wired into topgrade, replacing the built-in
  `claude_code_plugins` step) refreshes every marketplace and updates every installed plugin in
  every profile. A plugin that is installed but never enabled is re-cloned and re-updated on
  every run, forever.

An `enabledPlugins` entry set to `false` therefore means something narrower and rarer than
"unwanted": installed on purpose, switched off for now. There are currently none.

`claude-plugins-check-drift` (also wired into topgrade) enforces this file: it fails the run when
a plugin is installed but absent from `enabledPlugins`, when a declared plugin is not installed,
or when a registered marketplace is absent from `extraKnownMarketplaces`. That last check is what
catches a third-party marketplace left behind after its plugin is gone.

## Removing one

Both the plugin and — for a third-party marketplace with nothing else installed from it — the
marketplace registration must go, in **every** profile:

```shell
CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude/personal" claude plugin uninstall <plugin>@<marketplace>
CLAUDE_CONFIG_DIR="${XDG_CONFIG_HOME}/claude/work" claude plugin uninstall <plugin>@<marketplace>
```

Then drop the entry from `enabledPlugins` in `settings.json.tmpl`, add a section here, and run
`claude-plugins-check-drift` to confirm the profiles are clean.

## The list

### caveman

Ultra-compressed "caveman" communication mode plus commit/review/help variants. Drops articles
and filler to cut token usage. Installed from a third-party marketplace
(`JuliusBrussee/caveman`). Removed because it didn't seem to help and sometimes got in the way.

The `caveman` marketplace is removed along with it — it served no other plugin, and left
registered it would keep being refreshed on every topgrade run. Caveman also drops a
`.caveman-active` flag file at the root of each profile config dir; delete it too.

### explanatory-output-style

Recreates the deprecated "Explanatory" output style via a `SessionStart` hook. Injects
instructions encouraging Claude to provide educational insights about implementation choices and
codebase patterns, formatted as a `★ Insight` block with 2–3 key points. Superseded by the
`Concise` output style set in `settings.json`.

### frontend-design

Design system and component patterns for building production-grade frontend interfaces.

### gopls-lsp

Go language server (LSP) providing code intelligence for Go projects.

### lua-lsp

Lua language server (LSP) providing code intelligence for Lua projects.

### pyright-lsp

Python language server (LSP) providing type checking and code intelligence for Python projects.

### rust-analyzer-lsp

Rust language server (LSP) providing code intelligence for Rust projects.

### typescript-lsp

TypeScript/JavaScript language server (LSP) providing code intelligence for TS/JS projects.

## Deliberately kept

- **`jdtls-lsp`** — the one language server that is enabled. Java is the language actually worked
  in here; the other five LSP plugins above are not.
- **`github`** — was installed in both profiles while absent from `enabledPlugins`, the
  undeclared case that motivated `claude-plugins-check-drift`. Resolved by declaring it rather
  than removing it: it is already on disk and complements the `github` MCP server.
