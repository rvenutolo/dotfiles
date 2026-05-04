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
  message="
============================================================================================================================
⚠️⚠️⚠️ It is past ${bedtime_display}. You should considering wrapping up work for the day. You sleep poorly when you don't. ⚠️⚠️⚠️
============================================================================================================================"
  jq --null-input --arg msg "${message}" '{systemMessage: $msg}'
else
  echo "{}"
fi
