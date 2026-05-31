#!/usr/bin/env bash
# Sourced only at bash login (from bash_profile.bash, after .bashrc has
# run). Uses inline `command -v` because the __* helpers from env.bash
# are already unset by interactive.bash at this point.

if command -v fastfetch > /dev/null 2>&1; then
  fastfetch
fi
