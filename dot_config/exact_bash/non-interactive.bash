#!/usr/bin/env bash

# Sourced in every bash shell (interactive and non-interactive) from
# bashrc.bash. Bash-specific env setup that must run regardless of
# interactivity. Anything that produces output, calls `complete`, or
# otherwise assumes an interactive shell belongs in interactive.bash.

# SDKMAN init. Sets PATH and defines the `sdk` shell function so SDKMAN
# candidates are available in non-interactive bash (e.g. `ssh host 'sdk
# list'`). Pre-set sdkman_auto_complete=false because sdkman-init.sh
# calls the `complete` builtin, which is unavailable in non-interactive
# shells and would print an error. interactive.bash re-sources
# sdkman-init.sh with completion enabled.
# shellcheck disable=SC2034  # consumed by sdkman-init.sh below
sdkman_auto_complete=false
if [[ -r "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi
unset sdkman_auto_complete
