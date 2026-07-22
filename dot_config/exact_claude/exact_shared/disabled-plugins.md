# Disabled Plugin Bug Notes (May 2026)

Setting a plugin to `false` in `enabledPlugins` in `settings.json` does not fully disable it.
Two known bugs affect disabled plugins:

## Bug 1: Skills still appear in system prompt

Skills from disabled plugins still appear in the system prompt's skill list, consuming
context window tokens even when the plugin is disabled.

- https://github.com/anthropics/claude-code/issues/34940
- https://github.com/anthropics/claude-code/issues/40789

## Bug 2: Hooks still fire

`SessionStart` and `UserPromptSubmit` hooks from disabled plugins continue to fire,
injecting context into the conversation window on every session and every message.
A plugin with a large `SessionStart` hook (e.g. a 15KB knowledge graph) can consume
15–20% of the context window before the user says anything.

- https://github.com/anthropics/claude-code/issues/35713

## Uninstalled Plugins

### caveman
Ultra-compressed "caveman" communication mode plus commit/review/help variants. Drops
articles and filler to cut token usage. Installed from a third-party marketplace
(`JuliusBrussee/caveman`). Removed because it didn't seem to help and sometimes got in
the way.

```json
"caveman@caveman": true,
```

### explanatory-output-style
Recreates the deprecated "Explanatory" output style via a `SessionStart` hook. Injects
instructions encouraging Claude to provide educational insights about implementation
choices and codebase patterns, formatted as a `★ Insight` block with 2–3 key points.

```json
"explanatory-output-style@claude-plugins-official": true,
```

### frontend-design
Design system and component patterns for building production-grade frontend interfaces.

```json
"frontend-design@claude-plugins-official": true,
```

### gopls-lsp
Go language server (LSP) providing code intelligence for Go projects.

```json
"gopls-lsp@claude-plugins-official": true,
```

### lua-lsp
Lua language server (LSP) providing code intelligence for Lua projects.

```json
"lua-lsp@claude-plugins-official": true,
```

### pyright-lsp
Python language server (LSP) providing type checking and code intelligence for Python projects.

```json
"pyright-lsp@claude-plugins-official": true,
```

### rust-analyzer-lsp
Rust language server (LSP) providing code intelligence for Rust projects.

```json
"rust-analyzer-lsp@claude-plugins-official": true,
```

### typescript-lsp
TypeScript/JavaScript language server (LSP) providing code intelligence for TS/JS projects.

```json
"typescript-lsp@claude-plugins-official": true,
```
