#!/usr/bin/env bash
# chezmoi modify_ script: inject stdio MCP server registrations into a Claude Code
# .claude.json, leaving everything else byte-for-byte intact. Claude Code owns the rest
# of that file (session history, per-project state), so this only ever touches the
# .mcpServers["<name>"] keys it is given.
#
#   stdin  = current target contents (empty when the file does not yet exist)
#   stdout = new target contents
set -Eeuo pipefail
IFS=$'\n\t'

# JSON array of {name, command, args, env?, alwaysLoad?} objects, one per server to
# register. env defaults to {}; alwaysLoad is written only when given, so Claude Code
# keeps its own default (honour each tool's _meta flag) for servers that omit it.
readonly SERVERS_JSON='{{ .servers | toJson }}'

# Slurp stdin with builtins only. An external `cat` would have to run before the bail
# trap below is armed, so a `cat` missing from PATH would emit an empty file -- the exact
# outcome the trap exists to prevent. `read -d ''` reads to EOF (returning 1 there) and,
# unlike "$(cat)", preserves a trailing newline if the target ever has one.
original=''
IFS= read -r -d '' original || true

# A truncated or empty .claude.json would destroy live session state. On ANY failure --
# missing jq, malformed input, a jq error -- re-emit the original bytes unchanged *and*
# exit non-zero: whichever way chezmoi handles the failure, the target is preserved.
trap 'printf "%s" "${original}"; exit 1' ERR

command -v jq > /dev/null 2>&1

# Scan for the first non-whitespace character rather than stripping every whitespace
# character out of the string: `${input//[[:space:]]/}` is superlinear in bash and takes
# ~90s on a 190 KB .claude.json, which would make every `chezmoi apply` crawl.
input="${original}"
if [[ ! "${input}" =~ [^[:space:]] ]]; then
  input='{}'
fi

# Bare assignment (no `if !`, no `||`) so a jq failure reaches the ERR trap rather than
# being swallowed by the conditional. jq creates .mcpServers on demand, so `{}` works.
patched="$(
  printf '%s' "${input}" | jq \
    --argjson servers "${SERVERS_JSON}" \
    'reduce $servers[] as $s (.; .mcpServers[$s.name] = {type: "stdio", command: $s.command, args: $s.args, env: ($s.env // {})} + (if $s | has("alwaysLoad") then {alwaysLoad: $s.alwaysLoad} else {} end))'
)"

# Guard against jq exiting 0 with unusable output; either failure trips the ERR trap.
[[ -n "${patched}" ]]
printf '%s' "${patched}" | jq --exit-status 'type == "object"' > /dev/null

# Claude Code writes this file with no trailing newline. The command substitution above
# already stripped the one jq adds; printf '%s' avoids adding it back, so chezmoi sees
# no spurious whole-file diff.
printf '%s' "${patched}"
