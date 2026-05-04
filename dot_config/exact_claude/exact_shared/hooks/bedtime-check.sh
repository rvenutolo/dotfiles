#!/usr/bin/env bash
set -euo pipefail

hour="$(date +%H)"

if [[ "${hour}" -ge 22 ]] || [[ "${hour}" -lt 6 ]]; then
  current_time="$(date +%H:%M)"
  cat <<EOF
{
  "additionalContext": "⚠️  BEDTIME NOTICE: It is currently ${current_time}, past the user's 10pm cutoff. They have asked you to remind them to stop working when this happens. Please: (1) flag this prominently, (2) wrap up your current response naturally, and (3) encourage them to close up and get some sleep."
}
EOF
else
  echo "{}"
fi
