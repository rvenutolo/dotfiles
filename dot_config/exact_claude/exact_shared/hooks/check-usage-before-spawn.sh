#!/usr/bin/env bash

# PreToolUse hook — gates new subagent (Task) spawning on 5-hour usage.
# If usage is at or above THRESHOLD, sleeps until the window resets, then
# exits 0 so Claude proceeds automatically without human intervention.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
readonly THRESHOLD=85          # Block new agents at this % of 5-hour window
readonly USAGE_ENDPOINT='https://api.anthropic.com/api/oauth/usage'
readonly BETA_HEADER='anthropic-beta: oauth-2025-04-20'
readonly POLL_INTERVAL=60      # Seconds between re-checks while waiting
readonly MIN_SLEEP=60          # Never sleep less than this (1 minute)
readonly EXTRA_BUFFER=180      # Extra seconds to wait after nominal reset time (3 minutes)
readonly CREDENTIAL="${CLAUDE_CONFIG_DIR}/.credentials.json"

# ── Helpers ──────────────────────────────────────────────────────────────────


log() {
    # Writes to stderr — Claude Code surfaces this as feedback to the model.
    echo "$*" >&2
}

# Returns the OAuth access token, or empty string on failure.
get_token() {
    if [[ ! -f "${CREDENTIAL}" ]]; then
        echo ''
        return
    fi
    jq --raw-output '.claudeAiOauth.accessToken // empty' "${CREDENTIAL}" 2>/dev/null || echo ''
}

# Fetches usage JSON from the OAuth endpoint.
# Prints the raw JSON on success; empty string on failure.
fetch_usage() {
    local -r token="$1"
    curl \
        --silent \
        --fail \
        --header "Authorization: Bearer ${token}" \
        --header "${BETA_HEADER}" \
        "${USAGE_ENDPOINT}" 2>/dev/null || echo ''
}

# Pretty-prints a Unix epoch as a human-readable local time.
epoch_to_human() {
    local -r epoch="$1"
    date --date="@${epoch}" '+%Y-%m-%d %H:%M:%S %Z'
}

# ── Main ─────────────────────────────────────────────────────────────────────

input="$(cat)"
readonly input
tool_name="$(echo "${input}" | jq --raw-output '.tool_name // empty')"
readonly tool_name

# Only gate Task (subagent) spawning; pass everything else through.
if [[ "${tool_name}" != 'Task' ]]; then
    exit 0
fi

token="$(get_token)"
if [[ -z "${token}" ]]; then
    # Can't check usage — allow the spawn and let Claude handle any limit error.
    log 'check-usage-before-spawn: could not read OAuth token; skipping usage check.'
    exit 0
fi

# Loop: check usage, sleep if needed, re-check, eventually proceed.
while true; do
    usage_json="$(fetch_usage "${token}")"

    if [[ -z "${usage_json}" ]]; then
        log 'check-usage-before-spawn: usage endpoint unreachable; skipping usage check.'
        exit 0
    fi

    five_hour_pct="$(echo "${usage_json}" | jq --raw-output '.five_hour.used_percentage // 0')"
    resets_at_epoch="$(echo "${usage_json}"  | jq --raw-output '.five_hour.resets_at // empty')"

    # If usage is below threshold, allow the spawn immediately.
    if (( $(echo "${five_hour_pct} < ${THRESHOLD}" | bc --mathlib) )); then
        exit 0
    fi

    # ── Over threshold: explain and calculate sleep duration ─────────────────

    if [[ -n "${resets_at_epoch}" ]]; then
        now_epoch="$(date '+%s')"
        sleep_secs=$(( resets_at_epoch - now_epoch + EXTRA_BUFFER ))
        reset_human="$(epoch_to_human "${resets_at_epoch}")"

        if (( sleep_secs < MIN_SLEEP )); then
            sleep_secs="${MIN_SLEEP}"
        fi

        log ''
        log '┌─ Claude Code usage gate ───────────────────────────────────────────┐'
        log "│ 5-hour window: ${five_hour_pct}% used (threshold: ${THRESHOLD}%)"
        log "│ Window resets: ${reset_human}"
        log "│ Sleeping ${sleep_secs}s, then retrying automatically — no action needed."
        log '└────────────────────────────────────────────────────────────────────┘'
        log ''

        sleep "${sleep_secs}"
        # Re-fetch a fresh token after a potentially long sleep.
        token="$(get_token)"
        if [[ -z "${token}" ]]; then
            log 'check-usage-before-spawn: token gone after sleep; skipping usage check.'
            exit 0
        fi
    else
        # No reset time available — fall back to polling on a fixed interval.
        log ''
        log '┌─ Claude Code usage gate ───────────────────────────────────────────┐'
        log "│ 5-hour window: ${five_hour_pct}% used (threshold: ${THRESHOLD}%)"
        log "│ Reset time unknown. Retrying in ${POLL_INTERVAL}s automatically."
        log '└────────────────────────────────────────────────────────────────────┘'
        log ''

        sleep "${POLL_INTERVAL}"
        token="$(get_token)"
        if [[ -z "${token}" ]]; then
            log 'check-usage-before-spawn: token gone after sleep; skipping usage check.'
            exit 0
        fi
    fi

    # Loop back and re-check usage after sleeping.
done
