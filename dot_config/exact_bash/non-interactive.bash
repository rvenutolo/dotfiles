#!/usr/bin/env bash

# Sourced in every bash shell (interactive and non-interactive) from
# bashrc.bash. Bash-specific env setup that must run regardless of
# interactivity. Anything that produces output, calls `complete`, or
# otherwise assumes an interactive shell belongs in interactive.bash.

# SDKMAN fast path: export <CANDIDATE>_HOME and prepend <candidate>/current/bin
# to PATH for every installed candidate — the environment sdkman-init.sh's
# eager loop builds, without its ~160 ms cost in every shell. Pure parameter
# expansion, no subprocesses. Interactive shells additionally source the full
# init (see interactive.bash) for the `sdk` function and cd auto-switching.
# SDKMAN_CANDIDATES_DIR is exported too — external scripts (e.g. the scripts
# repo's java-installed) and sdkman's contrib completion read it without
# running the full init.
if [[ -d "${SDKMAN_DIR}/candidates" ]]; then
  export SDKMAN_CANDIDATES_DIR="${SDKMAN_DIR}/candidates"
  for __sdkman_current in "${SDKMAN_DIR}/candidates"/*/current; do
    if [[ -d "${__sdkman_current}" ]]; then
      __sdkman_name="${__sdkman_current%/current}"
      __sdkman_name="${__sdkman_name##*/}"
      if [[ "${__sdkman_name}" =~ ^[a-zA-Z][a-zA-Z0-9]*$ ]]; then
        export "${__sdkman_name^^}_HOME=${__sdkman_current}"
        if [[ ":${PATH}:" != *":${__sdkman_current}/bin:"* ]]; then
          PATH="${__sdkman_current}/bin:${PATH}"
        fi
      fi
    fi
  done
  # Apply ./.sdkmanrc (project-pinned versions, `candidate=version` lines) the
  # way `sdk env` would, so non-interactive shells started in a project root —
  # e.g. every Claude Code tool call — use the pinned JDK. Matches sdkman
  # semantics: only the current directory is consulted, no upward search.
  # Pinned bins are prepended after the loop above, so they win over current/.
  if [[ -f '.sdkmanrc' ]]; then
    while IFS='=' read -r __sdkman_name __sdkman_version || [[ -n "${__sdkman_name}" ]]; do
      __sdkman_name="${__sdkman_name//[[:space:]]/}"
      __sdkman_version="${__sdkman_version//[[:space:]]/}"
      if [[ "${__sdkman_name}" =~ ^[a-zA-Z][a-zA-Z0-9]*$ && -n "${__sdkman_version}" ]]; then
        __sdkman_pinned="${SDKMAN_DIR}/candidates/${__sdkman_name}/${__sdkman_version}"
        if [[ -d "${__sdkman_pinned}" ]]; then
          export "${__sdkman_name^^}_HOME=${__sdkman_pinned}"
          if [[ ":${PATH}:" != *":${__sdkman_pinned}/bin:"* ]]; then
            PATH="${__sdkman_pinned}/bin:${PATH}"
          fi
        else
          printf 'sdkman: .sdkmanrc pins %s %s but it is not installed - run "sdk env install"\n' \
            "${__sdkman_name}" "${__sdkman_version}" >&2
        fi
      fi
    done < '.sdkmanrc'
  fi
  export PATH
  unset -v __sdkman_current __sdkman_name __sdkman_version __sdkman_pinned
fi
