#!/usr/bin/env bash

set -euo pipefail

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

readonly link_file='/etc/exports.d/storage.exports'
readonly target_file="${XDG_CONFIG_HOME}/nfs/storage.exports"

if ! is_desktop || ! is_personal; then
  exit 0
fi
if ! executable_exists 'nfsstat'; then
  exit 0
fi
if [[ -L "${link_file}" && "$(readlink --canonicalize "${link_file}")" == "$(readlink --canonicalize "${target_file}")" ]]; then
  exit 0
fi
if [[ -f "${link_file}" ]]; then
  diff --color --unified "${link_file}" "${target_file}" || true
  if ! prompt_yn "${link_file} exists - Link: ${target_file} -> ${link_file}?"; then
    exit 0
  fi
else
  if ! prompt_yn "Link: ${target_file} -> ${link_file}?"; then
    exit 0
  fi
fi

log "Linking: ${target_file} -> ${link_file}"
if [[ -f "${link_file}" ]]; then
  sudo rm "${link_file}"
fi
sudo mkdir --parents "$(dirname "${link_file}")"
sudo ln --symbolic "${target_file}" "${link_file}"
log "Linked: ${target_file} -> ${link_file}"

if prompt_yn "Re-export NFS server exports?"; then
  log 'Re-exporting NFS exports'
  sudo exportfs -arv
  log 'Re-exported NFS exports'
fi