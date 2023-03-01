#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

function enable_service() {
  local service_unit="$1"
  local service_desc="$2"
  local system_or_user="$3"
  local executable="$4-"

  if [[ -n "${executable}" ]] && ! executable_exists "${executable}"; then
    exit 0
  fi

  if ! systemctl is-enabled --"${system_or_user}" --quiet "${service_unit}" && prompt_yn "Enable and start ${service_desc} service?"; then
    log "Enabling and starting ${service_desc} service"
    systemctl enable --now --"${system_or_user}" --quiet "${service_unit}"
    log "Enabled and started ${service_desc} service"
  fi

  if ! systemctl is-active --"${system_or_user}" --quiet "${service_unit}" && prompt_yn "Start ${service_desc} service?"; then
    log "Starting ${service_desc} service"
    systemctl start --"${system_or_user}" --quiet "${service_unit}"
    log "Started ${service_desc} service"
  fi
}

enable_service 'apparmor.service' 'App Armor' 'system' 'aa-enabled'
enable_service 'autotrash.timer' 'Autotrash' 'user' 'autotrash'
enable_service 'crashplan-pro.service' 'CrashPlan' 'system' 'CrashPlanDesktop'
enable_service 'cups.service' 'CUPS' 'system' 'cupsctl'
enable_service 'fail2ban.service' 'fail2ban' 'system' 'fail2ban-server'
enable_service 'journalctl-vacuum.timer' 'journnalctl-vacuum' 'user'
enable_service 'libvirtd.service' 'libvirtd' 'system' 'libvirtd'
enable_service 'nfsv4-server.service' 'NFS v4' 'system' 'exportfs'
## TODO check if reflector should be a user or system service
enable_service 'reflector.service' 'Reflector' 'system' 'reflector'
enable_service 'sshd.service' 'SSH daemon' 'system' 'sshd'
enable_service 'ssh-agent.service' 'SSH key agent' 'user' 'ssh-agent'
enable_service 'ufw.service' 'UFW' 'system' 'ufw'
