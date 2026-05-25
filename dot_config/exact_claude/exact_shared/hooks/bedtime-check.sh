#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
trap 'printf "error: line %s (exit %d): %s\n" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR

readonly BEDTIME_START=22
readonly BEDTIME_END=6

if ((BEDTIME_START == 0)); then
  bedtime_display='12am'
elif ((BEDTIME_START == 12)); then
  bedtime_display='12pm'
elif ((BEDTIME_START > 12)); then
  bedtime_display="$((BEDTIME_START - 12))pm"
else
  bedtime_display="${BEDTIME_START}am"
fi
readonly bedtime_display

hour="$(date '+%-H')"
readonly hour

if ((hour >= BEDTIME_START)) || ((hour < BEDTIME_END)); then
  message="
=================================================================================================================
⚠️⚠️⚠️ It is past ${bedtime_display}. You should consider wrapping up work for the day. You sleep poorly when you don't. ⚠️⚠️⚠️
================================================================================================================="
  jq --null-input --arg msg "${message}" '{systemMessage: $msg}'
else
  printf '{}\n'
fi
