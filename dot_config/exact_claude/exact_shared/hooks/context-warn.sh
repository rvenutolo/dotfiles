#!/usr/bin/env bash
set -euo pipefail

input="$(cat)"

used="$(echo "${input}" | jq -r '.context_window.used_percentage // 0')"
used_int="${used%.*}"

if (( used_int >= 50 )); then
  echo "⚠️  Context at ${used_int}% — consider running /compact" >&2
fi

exit 0
