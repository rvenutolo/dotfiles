#!/usr/bin/env bash

set -euo pipefail

set +u
source "${XDG_CONFIG_HOME}/bash/functions"
source "${XDG_CONFIG_HOME}/bash/exports"
set -u

if executable_exists 'aws'; then
  exit 0
fi
if ! prompt_yn 'Install AWS CLI?'; then
  exit 0
fi

log 'Installing AWS CLI'
if ! executable_exists 'unzip'; then
  log 'Downloading unzip'
  curl --silent --show-error --location --output '/tmp/unzip.tar.zst' 'https://archlinux.org/packages/extra/x86_64/unzip/download/'
  tar --extract --use-compress-program=unzstd --file '/tmp/unzip.tar.zst' --directory '/tmp' 'usr/bin/unzip'
  chmod +x '/tmp/usr/bin/unzip'
  PATH="/tmp/usr/bin:${PATH}"
  log 'Downloaded unzip'
fi
readonly aws_cli_url='https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip'
readonly aws_cli_tmp_dir="$(mktemp --directory)"
readonly aws_cli_zip_file="${aws_cli_tmp_dir}/aws_cli.zip"
curl --silent --show-error --location --output "${aws_cli_zip_file}" "${aws_cli_url}"
unzip -q "${aws_cli_zip_file}" -d "${aws_cli_tmp_dir}"
sudo "${aws_cli_tmp_dir}/aws/install" --bin-dir '/usr/local/bin' --install-dir '/usr/local/aws-cli' --update
log 'Installed AWS CLI'
