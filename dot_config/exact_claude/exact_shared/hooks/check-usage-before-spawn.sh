#!/usr/bin/env bash

# PreToolUse hook — gates new subagent (Task) spawning on 5-hour usage.
# If usage is at or above THRESHOLD, sleeps until the window resets, then
# exits 0 so Claude proceeds automatically without human intervention.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
readonly THRESHOLD=85 # Block new agents at this % of 5-hour window
readonly USAGE_ENDPOINT='https://api.anthropic.com/api/oauth/usage'
readonly BETA_HEADER='anthropic-beta: oauth-2025-04-20'
readonly POLL_INTERVAL=60     # Seconds between re-checks while waiting
readonly MIN_SLEEP=60         # Never sleep less than this (1 minute)
readonly EXTRA_BUFFER=180     # Extra seconds to wait after nominal reset time (3 minutes)
readonly MAX_ITERATIONS=12    # Cap total wait loops to avoid pathological infinite waits
readonly MAX_TOTAL_WAIT=21600 # Hard ceiling on cumulative sleep (6 hours)
readonly CREDENTIAL="${CLAUDE_CONFIG_DIR:-}/.credentials.json"

# ── Helpers ──────────────────────────────────────────────────────────────────

function log() {
  # Writes to stderr — visible to user via Ctrl-R transcript; not fed to model
  # (PreToolUse exit 0 allows the call without surfacing stderr to the model).
  echo "$*" >&2
}

# Verify required CLI tools are present.
for cmd in curl jq awk date; do
  if ! command -v "${cmd}" > /dev/null 2>&1; then
    log "check-usage-before-spawn: required tool '${cmd}' missing; skipping usage check."
    exit 0
  fi
done

# Returns the OAuth access token, or empty string on failure.
function get_token() {
  if [[ ! -f "${CREDENTIAL}" ]]; then
    echo ''
    return
  fi
  jq --raw-output '.claudeAiOauth.accessToken // empty' "${CREDENTIAL}" 2> /dev/null || echo ''
}

# Fetches usage JSON. Writes JSON to stdout; HTTP status to FD 3 of caller.
# Returns 0 on HTTP 2xx, 1 on auth failure (401/403), 2 on network/other error.
function fetch_usage() {
  local -r token="$1"
  local body http_code curl_rc=0
  local -r tmp="$(mktemp)"

  http_code="$(
    curl \
      --silent \
      --output "${tmp}" \
      --write-out '%{http_code}' \
      --header "Authorization: Bearer ${token}" \
      --header "${BETA_HEADER}" \
      "${USAGE_ENDPOINT}" 2> /dev/null
  )" || curl_rc=$?

  body="$(cat "${tmp}")"
  rm --force -- "${tmp}"

  if ((curl_rc != 0)) || [[ -z "${http_code}" ]]; then
    echo ''
    return 2
  fi

  case "${http_code}" in
    2*)
      printf '%s' "${body}"
      return 0
      ;;
    401 | 403)
      echo ''
      return 1
      ;;
    *)
      echo ''
      return 2
      ;;
  esac
}

# Pretty-prints a Unix epoch as a human-readable local time.
function epoch_to_human() {
  local -r epoch="$1"
  date --date="@${epoch}" '+%Y-%m-%d %H:%M:%S %Z'
}

# Returns 0 if first numeric arg is strictly less than second; else 1. No bc dep.
function numeric_lt() {
  awk -v a="$1" -v b="$2" 'BEGIN { exit !(a < b) }'
}

# ── Main ─────────────────────────────────────────────────────────────────────

input="$(cat)"
readonly input
tool_name="$(printf '%s' "${input}" | jq --raw-output '.tool_name // empty')"
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

iteration=0
total_waited=0

# Loop: check usage, sleep if needed, re-check, eventually proceed.
while true; do
  usage_json=''
  fetch_rc=0
  usage_json="$(fetch_usage "${token}")" || fetch_rc=$?

  case "${fetch_rc}" in
    0) ;;
    1)
      log 'check-usage-before-spawn: auth rejected (401/403); skipping usage check.'
      exit 0
      ;;
    *)
      log 'check-usage-before-spawn: usage endpoint unreachable; skipping usage check.'
      exit 0
      ;;
  esac

  if [[ -z "${usage_json}" ]]; then
    log 'check-usage-before-spawn: empty usage response; skipping usage check.'
    exit 0
  fi

  five_hour_pct="$(printf '%s' "${usage_json}" | jq --raw-output '.five_hour.used_percentage // 0')"
  resets_at_epoch="$(printf '%s' "${usage_json}" | jq --raw-output '.five_hour.resets_at // empty')"

  # If usage is below threshold, allow the spawn immediately.
  if numeric_lt "${five_hour_pct}" "${THRESHOLD}"; then
    exit 0
  fi

  # ── Over threshold: enforce caps before sleeping ─────────────────────────
  iteration=$((iteration + 1))
  if ((iteration > MAX_ITERATIONS)); then
    log "check-usage-before-spawn: hit iteration cap (${MAX_ITERATIONS}); allowing spawn."
    exit 0
  fi
  if ((total_waited >= MAX_TOTAL_WAIT)); then
    log "check-usage-before-spawn: hit total wait cap (${MAX_TOTAL_WAIT}s); allowing spawn."
    exit 0
  fi

  # ── Calculate sleep duration ─────────────────────────────────────────────

  if [[ -n "${resets_at_epoch}" ]]; then
    now_epoch="$(date '+%s')"
    sleep_secs=$((resets_at_epoch - now_epoch + EXTRA_BUFFER))
    reset_human="$(epoch_to_human "${resets_at_epoch}")"

    if ((sleep_secs < MIN_SLEEP)); then
      sleep_secs="${MIN_SLEEP}"
    fi

    log ''
    log '┌─ Claude Code usage gate ───────────────────────────────────────────┐'
    log "│ 5-hour window: ${five_hour_pct}% used (threshold: ${THRESHOLD}%)"
    log "│ Window resets: ${reset_human}"
    log "│ Sleeping ${sleep_secs}s, then retrying automatically — no action needed."
    log '└────────────────────────────────────────────────────────────────────┘'
    log ''
  else
    sleep_secs="${POLL_INTERVAL}"

    log ''
    log '┌─ Claude Code usage gate ───────────────────────────────────────────┐'
    log "│ 5-hour window: ${five_hour_pct}% used (threshold: ${THRESHOLD}%)"
    log "│ Reset time unknown. Retrying in ${POLL_INTERVAL}s automatically."
    log '└────────────────────────────────────────────────────────────────────┘'
    log ''
  fi

  sleep "${sleep_secs}"
  total_waited=$((total_waited + sleep_secs))

  # Re-fetch a fresh token after a potentially long sleep.
  token="$(get_token)"
  if [[ -z "${token}" ]]; then
    log 'check-usage-before-spawn: token gone after sleep; skipping usage check.'
    exit 0
  fi

  # Loop back and re-check usage after sleeping.
done
