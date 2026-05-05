#!/usr/bin/env bash
set -euo pipefail

# Hook — warns when context window usage exceeds the threshold.
# Works with any hook type: uses native context_window data when available
# (e.g. PreToolUse), falls back to transcript JSONL parsing (e.g. Stop).

readonly THRESHOLD=80

# Returns context window usage percentage (0-100).
#
# Priority:
#   1. context_window.used_percentage from hook JSON (native, Claude Code v2.1.6+)
#   2. Token sum / context_window.context_window_size from hook JSON
#   3. Last assistant message tokens / fallback_window_size parsed from transcript JSONL
#
# Args:
#   $1 - hook stdin JSON (capture with: hook_data=$(cat) before calling)
#   $2 - fallback context window size in tokens (default: 200000)
#        Only used when context_window data is absent from stdin.
#        Common values: 200000 (Claude 3.x/4.x), 1048576 (1M-context models)
#
# Requires: jq
get_context_percent() {
  local hook_json
  hook_json="${1:-}"
  local -r hook_json

  local fallback_window_size
  fallback_window_size="${2:-200000}"
  local -r fallback_window_size

  if [[ -n "${hook_json}" ]]; then
    # 1. Native used_percentage (statusline stdin format, Claude Code v2.1.6+).
    #    A value of 0 is treated as "not yet populated" — fall through.
    local native
    native="$(printf '%s' "${hook_json}" | jq -r '.context_window.used_percentage // empty' 2>/dev/null)" || native=""
    local -r native
    if [[ -n "${native}" ]] && jq -en --argjson v "${native}" '$v > 0' >/dev/null 2>&1; then
      jq -rn --argjson v "${native}" '[$v, 100] | min | floor' 2>/dev/null || printf '0\n'
      return 0
    fi

    # 2. Token sum / context_window_size (also statusline stdin format).
    local cw_size
    cw_size="$(printf '%s' "${hook_json}" | jq -r '.context_window.context_window_size // empty' 2>/dev/null)" || cw_size=""
    local -r cw_size
    if [[ "${cw_size}" =~ ^[0-9]+$ ]] && [[ "${cw_size}" -gt 0 ]]; then
      local cw_total
      cw_total="$(printf '%s' "${hook_json}" | jq -r '
        .context_window.current_usage as $u |
        ($u.input_tokens // 0) +
        ($u.cache_creation_input_tokens // 0) +
        ($u.cache_read_input_tokens // 0)
      ' 2>/dev/null)" || cw_total=0
      local -r cw_total
      if [[ "${cw_total}" =~ ^[0-9]+$ ]] && [[ "${cw_total}" -gt 0 ]]; then
        jq -rn \
          --argjson total "${cw_total}" \
          --argjson size "${cw_size}" \
          '[$total / $size * 100, 100] | min | floor' 2>/dev/null || printf '0\n'
        return 0
      fi
    fi
  fi

  # 3. Fallback: parse transcript JSONL for last assistant message token counts.
  #    Used when context_window is absent from stdin (e.g. Stop hooks).
  local transcript_path
  transcript_path=""
  if [[ -n "${hook_json}" ]]; then
    transcript_path="$(printf '%s' "${hook_json}" | jq -r '.transcript_path // empty' 2>/dev/null)" || transcript_path=""
  fi
  local -r transcript_path

  if [[ -z "${transcript_path}" || ! -f "${transcript_path}" ]]; then
    printf '0\n'
    return 0
  fi

  local raw_total
  raw_total="$(jq -Rn '
    [ inputs |
      try (
        fromjson |
        select(.type == "assistant" and (.message.usage != null)) |
        .message.usage
      ) catch empty
    ] |
    last // null |
    if . == null then 0
    else
      (.input_tokens // 0) +
      (.cache_creation_input_tokens // 0) +
      (.cache_read_input_tokens // 0)
    end
  ' "${transcript_path}" 2>/dev/null)" || raw_total=0
  local -r total="${raw_total:-0}"

  jq -rn \
    --argjson total "${total}" \
    --argjson size "${fallback_window_size}" \
    '[$total / $size * 100, 100] | min | floor' \
    2>/dev/null || printf '0\n'
}

input="$(cat)"
readonly input

used_pct="$(get_context_percent "${input}")"
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
