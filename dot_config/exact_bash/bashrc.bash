#!/usr/bin/env bash

# Sourced by bash for interactive non-login shells:
#   - Terminal tabs spawned from a desktop session.
#   - `bash` (no -l) invoked inside an existing shell.
# Also sourced indirectly (via bash_profile.bash) for interactive login
# shells. Also sourced directly by bash for *non-interactive* shells when
# stdin is a network connection (e.g. `ssh host '<cmd>'`) -- the guard
# below short-circuits that path.

# Sourced in all bash shells (interactive and non-interactive).
if [[ -r "${HOME}/.profile" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${HOME}/.profile"
fi
if [[ -r "${XDG_CONFIG_HOME}/bash/non-interactive.bash" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${XDG_CONFIG_HOME}/bash/non-interactive.bash"
fi

# Stop here for non-interactive shells. Bash sources ~/.bashrc when stdin
# is a network socket, even though the shell is non-interactive. Without
# this guard, completions and prompt setup would run there and pollute
# output (notably SDKMAN's `complete` call, which errors when the builtin
# is unavailable).
case $- in
  *i*) ;;
  *) return ;;
esac

# Sourced only in interactive shells.
if [[ -r "${XDG_CONFIG_HOME}/bash/interactive.bash" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${XDG_CONFIG_HOME}/bash/interactive.bash"
fi
