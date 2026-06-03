#!/usr/bin/env bash

# Sourced in every bash shell (interactive and non-interactive) from
# bashrc.bash. Bash-specific env setup that must run regardless of
# interactivity. Anything that produces output, calls `complete`, or
# otherwise assumes an interactive shell belongs in interactive.bash.

# Pre-set sdkman_auto_complete=false because sdkman-init.sh calls the
# `complete` builtin, which is unavailable in non-interactive shells.
# ${SDKMAN_DIR}/etc/config sets sdkman_auto_complete=true and is sourced
# inside sdkman-init.sh, clobbering this pre-set. Shadow `complete` as a
# no-op for the duration of the source to swallow the resulting error
# without patching SDKMAN itself. interactive.bash re-sources
# sdkman-init.sh later with completion enabled, by which point the shim
# is gone and the real builtin is in effect.
# shellcheck disable=SC2034  # consumed by sdkman-init.sh below
sdkman_auto_complete=false
complete() { :; }
if [[ -r "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi
unset -f complete
unset sdkman_auto_complete
