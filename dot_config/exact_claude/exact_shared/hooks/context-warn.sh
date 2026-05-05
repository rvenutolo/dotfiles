#!/usr/bin/env bash
set -euo pipefail

# Stop hook — reads the session transcript to compute context window usage
# and warns when usage exceeds the threshold.

readonly THRESHOLD=80

input="$(cat)"
readonly input

transcript_path="$(echo "${input}" | jq --raw-output '.transcript_path')"
readonly transcript_path
model="$(echo "${input}" | jq --raw-output '.model // "unknown"')"
readonly model

# Derive context window from model id. Claude Code appends [1m] suffix for the
# 1M context variant; everything else uses the standard 200K window.
if [[ "${model}" == *"[1m]"* ]]; then
  context_window=1000000
else
  context_window=200000
fi
readonly context_window

# Sum token counts from the most recent assistant message in the transcript.
# input_tokens + cache_read_input_tokens + cache_creation_input_tokens = full input;
# output_tokens = tokens generated this turn (in context for next turn).
total_tokens="$(jq --slurp '
  [.[] | select(.message.usage != null) | .message.usage] | last // {}
  | (.input_tokens // 0)
    + (.cache_read_input_tokens // 0)
    + (.cache_creation_input_tokens // 0)
    + (.output_tokens // 0)
' "${transcript_path}")"
readonly total_tokens

used_pct=$(( total_tokens * 100 / context_window ))
readonly used_pct

if (( used_pct >= THRESHOLD )); then
  message="
======================================================================
⚠️⚠️⚠️ Context at ${used_pct}%. You should consider running /compact. ⚠️⚠️⚠️
======================================================================"
  readonly message
  jq --null-input --arg msg "${message}" '{systemMessage: $msg}'
fi

exit 0
