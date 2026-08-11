# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Install & Init

```shell
## SET HOSTNAME FIRST
adduser rvenutolo && usermod -aG sudo rvenutolo && ssh -o StrictHostKeyChecking=no rvenutolo@localhost
eval $(ssh-agent)
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /tmp ## OR sh -c "$(wget -qO- get.chezmoi.io)" -- -b /tmp
SCRIPTS_AUTO_ANSWER=y /tmp/chezmoi init --apply rvenutolo
. ~/.bash_profile
SCRIPTS_AUTO_ANSWER=y ~/Projects/Personal/scripts/run-install-scripts
SCRIPTS_AUTO_ANSWER=y ~/Projects/Personal/scripts/run-set-up-scripts
```

## How It Works

- [`.chezmoidata.yaml`](.chezmoidata.yaml) is the canonical source of truth for
  shared facts: hostnames, paths, the git repo list, the age public key, the
  weather city. Chezmoi loads it automatically; any `*.tmpl` file reads the
  values as `.hostnames.*`, `.paths.*`, `.age.*`, etc.
- The shell gets the same values via `dot_config/profile.sh.tmpl`, which renders
  `export FOO=...` lines into `~/.config/profile.sh` on apply. One source feeds
  both chezmoi templates and the shell.
- `~/.config/profile.sh` is rendered, not authored — never edit the target file;
  the next `chezmoi apply` overwrites it. Edit the template (or
  `.chezmoidata.yaml`) instead.
- Paths in `.chezmoidata.yaml` are home-relative (no leading slash); templates
  join them with the target home dir when an absolute path is needed.
- `{{ env "FOO" }}` is banned for shared facts (a pre-commit hook enforces it):
  `env` reads the current shell, which has nothing exported during a
  fresh-machine `chezmoi init`.
- To add a new shared fact: add it to `.chezmoidata.yaml` and, if the shell
  needs it, to `dot_config/profile.sh.tmpl` — never one without the other.

Full conventions (source-state prefixes, templating, encryption, script rules):
see [CLAUDE.md](CLAUDE.md).

## Remove Dirs to Reset Chezmoi State

```shell
rm -rf ~/.config/chezmoi ~/.local/share/chezmoi
```
