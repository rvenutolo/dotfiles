#!/usr/bin/env bash
set -euo pipefail

readonly BEDTIME_START=22
readonly BEDTIME_END=6

if [[ "${BEDTIME_START}" -eq 0 ]]; then
  bedtime_display="12am"
elif [[ "${BEDTIME_START}" -eq 12 ]]; then
  bedtime_display="12pm"
elif [[ "${BEDTIME_START}" -gt 12 ]]; then
  bedtime_display="$((BEDTIME_START - 12))pm"
else
  bedtime_display="${BEDTIME_START}am"
fi
readonly bedtime_display

hour="$(date +%H)"
readonly hour

if [[ "${hour}" -ge "${BEDTIME_START}" ]] || [[ "${hour}" -lt "${BEDTIME_END}" ]]; then
  current_time="$(date +%H:%M)"
  readonly current_time
  cat <<EOF
{
  "additionalContext": "⚠️  BEDTIME NOTICE: It is currently ${current_time}, past the user's ${bedtime_display} cutoff. They have asked you to remind them to stop working when this happens. Please: (1) flag this prominently, (2) wrap up your current response naturally, and (3) encourage them to close up and get some sleep."
}
EOF
else
  echo "{}"
fi
