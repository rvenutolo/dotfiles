#!/usr/bin/env bash
# PreToolUse hook: block writes under docs/ in the chezmoi source state.
#
# Two reasons this path is always wrong here:
#   1. This repo is chezmoi source state -- an unignored docs/ would apply to
#      ~/docs on every target host.
#   2. The superpowers writing-plans skill hardcodes docs/superpowers/plans/,
#      but plans/specs/scratch/reports belong under .claude/ per CLAUDE.md.

set -Eeuo pipefail

input="$(cat)"

file_path="$(jq --raw-output '.tool_input.file_path // .tool_input.notebook_path // empty' <<< "${input}")"
if [[ -z "${file_path}" ]]; then
  exit 0
fi

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  exit 0
fi

# Normalize to a repo-relative path without requiring the file to exist.
abs_path="${file_path}"
if [[ "${abs_path}" != /* ]]; then
  abs_path="${PWD}/${abs_path}"
fi
rel_path="${abs_path#"${repo_root}"/}"

# Not under this repo, or not under docs/ -- allow.
if [[ "${abs_path}" == "${rel_path}" || "${rel_path}" != docs/* ]]; then
  exit 0
fi

case "${rel_path}" in
  *plan*) dest='.claude/plans/' ;;
  *spec*) dest='.claude/specs/' ;;
  *report*) dest='.claude/reports/' ;;
  *scratch*) dest='.claude/scratch/' ;;
  *) dest='.claude/plans/, .claude/specs/, .claude/scratch/, or .claude/reports/' ;;
esac

jq --null-input --arg dest "${dest}" --arg rel "${rel_path}" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: (
      "Blocked write to \($rel). This repo is chezmoi source state -- docs/ would apply to ~/docs on target hosts. Write to \($dest) instead. This overrides any skill (e.g. superpowers writing-plans) that names docs/superpowers/plans/."
    )
  }
}'
