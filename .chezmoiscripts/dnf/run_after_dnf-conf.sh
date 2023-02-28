#!/usr/bin/env bash

set -euo pipefail

## TODO remove this script once it is no longer a useful reference
exit 0

source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"

readonly dnf_conf_file='/etc/dnf/dnf.conf'

function setting_missing() {
  ! grep --perl-regexp --quiet "^\s*$1\s*=\s*\w+\s*$" "${dnf_conf_file}"
}

function find_commented_out_line() {
  grep --perl-regexp "^\s*#[#\s]*$1\s*=\s*\w+\s*$" "${dnf_conf_file}" || true
}

function replace_line_in_dnf_conf_file() {
  sudo sed -i "s|^$1$|$2|" "${dnf_conf_file}"
}

function append_to_dnf_conf_file() {
  echo "$1" | sudo tee -a "${dnf_conf_file}" > /dev/null
}

function add_dnf_conf() {
  local param="$1"
  local line="$1=$2"
  local commented_out_line
  commented_out_line="$(find_commented_out_line "${param}")"
  if [[ -z "${commented_out_line}" ]]; then
    append_to_dnf_conf_file "${line}"
  else
    replace_line_in_dnf_conf_file "${commented_out_line}" "${line}"
  fi
}

if ! executable_exists 'dnf'; then
  exit 0
fi

if [[ ! -f "${dnf_conf_file}" ]]; then
  echo "${dnf_conf_file} does not exist" >&2
  exit 2
fi

if setting_missing 'max_parallel_downloads' && prompt_yn "Set DNF max_parallel_downloads?"; then
  readonly mpd="$(prompt_for_value 'max_parallel_downloads value?' "$(nproc)")"
  add_dnf_conf 'max_parallel_downloads' "${mpd}"
fi

if setting_missing 'defaultyes' && prompt_yn 'Enable DNF defaultyes'; then
  add_dnf_conf 'defaultyes' 'True'
fi

if setting_missing 'keepcache' && prompt_yn 'Enable DNF keepcache'; then
  add_dnf_conf 'keepcache' 'True'
fi
