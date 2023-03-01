#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

if ! executable_exists 'ufw'; then
  exit 0
fi

readonly local_ip_num="$(ipv4_to_num "$(ip -oneline route get to '8.8.8.8' | sed --quiet 's/.*src \([0-9.]\+\).*/\1/p')")"
if [[ $(ipv4_to_num '10.0.0.0') -le "${local_ip_num}" && "${local_ip_num}" -le $(ipv4_to_num '10.255.255.255') ]]; then
  local_network='10.0.0.0/8'
elif [[ $(ipv4_to_num '172.16.0.0') -le "${local_ip_num}" && "${local_ip_num}" -le $(ipv4_to_num '172.31.255.255') ]]; then
  local_network='172.16.0.0/12'
elif [[ $(ipv4_to_num '192.168.0.0') -le "${local_ip_num}" && "${local_ip_num}" -le $(ipv4_to_num '192.168.255.255') ]]; then
  local_network='192.168.0.0/16'
else
  echo "Could not determine local network IPv4 range"
  exit 2
fi
readonly local_network

if ! sudo ufw status verbose | contains_word 'deny (incoming)'; then
  if prompt_yn 'Set UFW to deny incoming?'; then
    sudo ufw default deny incoming
  fi
fi

if ! sudo ufw status verbose | contains_word 'allow (outgoing)'; then
  if prompt_yn 'Set UFW to allow outgoing?'; then
    sudo ufw default allow outgoing
  fi
fi

if ! grep --perl-regexp --quiet --ignore-case "anywhere\s+allow in\s+${local_network}" <<< "$(sudo ufw status verbose)"; then
  if prompt_yn "Set UFW to allow from ${local_network}?"; then
    sudo ufw allow from "${local_network}"
  fi
fi

if ! sudo ufw status verbose | contains_word 'status: active'; then
  if prompt_yn 'Enable UFW?'; then
    sudo ufw enable
  fi
fi
