#!/usr/bin/env bash

# Sourced in every bash shell (interactive and non-interactive) from
# bashrc.bash. Bash-specific env setup that must run regardless of
# interactivity. Anything that produces output, calls `complete`, or
# otherwise assumes an interactive shell belongs in interactive.bash.

# SDKMAN fast path: export <CANDIDATE>_HOME and prepend <candidate>/current/bin
# to PATH for every installed candidate — the environment sdkman-init.sh's
# eager loop builds, without its ~160 ms cost in every shell. Pure parameter
# expansion, no subprocesses. The `sdk` function itself is lazy-loaded on
# first use (see interactive.bash).
if [[ -d "${SDKMAN_DIR}/candidates" ]]; then
  for __sdkman_current in "${SDKMAN_DIR}/candidates"/*/current; do
    if [[ -d "${__sdkman_current}" ]]; then
      __sdkman_name="${__sdkman_current%/current}"
      __sdkman_name="${__sdkman_name##*/}"
      if [[ "${__sdkman_name}" =~ ^[a-zA-Z0-9]+$ ]]; then
        export "${__sdkman_name^^}_HOME=${__sdkman_current}"
        if [[ ":${PATH}:" != *":${__sdkman_current}/bin:"* ]]; then
          PATH="${__sdkman_current}/bin:${PATH}"
        fi
      fi
    fi
  done
  export PATH
  unset -v __sdkman_current __sdkman_name
fi
