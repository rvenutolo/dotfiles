#!/usr/bin/env bash

# Sourced by bash for login shells (where bash starts with -l / --login,
# or argv[0] starts with `-`, e.g. `-bash`):
#   - Console TTY login.
#   - SSH login session (interactive `ssh host`).
#   - Explicit `bash --login` / `bash -l`.
# Not sourced for non-login shells (terminal tabs spawned from a desktop
# session), scripts, or `ssh host '<cmd>'` invocations.

if [[ -r "${HOME}/.profile" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${HOME}/.profile"
fi
if [[ -r "${HOME}/.bashrc" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${HOME}/.bashrc"
fi
if [[ -r "${XDG_CONFIG_HOME}/bash/login.bash" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${XDG_CONFIG_HOME}/bash/login.bash"
fi
