#!/usr/bin/env bash

# Sourced from bashrc.bash in interactive shells only. Bash-specific env
# setup: env vars, PATH tweaks, and tool init that only changes env state
# (no prompt, no completion, no UX). Helper functions are defined here
# and unset at the end of interactive.bash.

# helper functions used in this file and in interactive.bash
function __executable_exists() {
  type -aPf "$1" > /dev/null 2>&1
}
function __is_readable_file() {
  [[ -r "$1" ]]
}
function __path_remove() {
  PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"$1"'"' | sed 's/:$//')
}
function __path_append() {
  __path_remove "$1" && PATH="$PATH:$1"
}
function __path_prepend() {
  __path_remove "$1" && PATH="$1:$PATH"
}

# files that set env vars (like PATH)
for file in \
  "${NIX_USER_PROFILE}/etc/profile.d/nix.sh" \
  "${NIX_USER_PROFILE}/etc/profile.d/hm-session-vars.sh" \
  "${SDKMAN_DIR}/bin/sdkman-init.sh"; do
  if __is_readable_file "${file}"; then
    source "${file}"
  fi
done
unset -v file

# scripts dir PATH prepends
for dir in \
  "${SCRIPTS_DIR}/other" \
  "${SCRIPTS_DIR}/main"; do
  __path_prepend "${dir}"
done
unset -v dir

# GPG TTY (interactive shells have a real tty here)
export GPG_TTY="$(tty)"

# SSH_ASKPASS discovery.
# seahorse + gnome-ssh-askpass ship under libexec (FHS helper convention),
# which is not on PATH, so they're listed by absolute path.
for __askpass in ksshaskpass /usr/libexec/seahorse/ssh-askpass /usr/lib/seahorse/ssh-askpass /usr/libexec/openssh/gnome-ssh-askpass lxqt-openssh-askpass x11-ssh-askpass; do
  case "${__askpass}" in
    /*)
      if [[ -x "${__askpass}" ]]; then
        export SSH_ASKPASS="${__askpass}"
        break
      fi
      ;;
    *)
      if __executable_exists "${__askpass}"; then
        SSH_ASKPASS="$(command -v "${__askpass}")"
        export SSH_ASKPASS
        break
      fi
      ;;
  esac
done
unset __askpass
[[ -n "${SSH_ASKPASS:-}" ]] && export SSH_ASKPASS_REQUIRE='prefer'

# Tailscale IP/CIDR
if __executable_exists 'tailscale' && tailscale status > '/dev/null'; then
  export TAILNET_IP="$(tailscale ip -4)"
  export TAILNET_CIDR='100.64.0.0/10'
fi
