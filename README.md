# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Install & Init

```shell
adduser rvenutolo && usermod -aG sudo rvenutolo && ssh -o StrictHostKeyChecking=no rvenutolo@localhost
eval $(ssh-agent)
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /tmp ## OR sh -c "$(wget -qO- get.chezmoi.io)" -- -b /tmp
SCRIPTS_AUTO_ANSWER=y /tmp/chezmoi init --apply rvenutolo
. ~/.bash_profile
SCRIPTS_AUTO_ANSWER=y ~/Code/Personal/scripts/run-install-scripts
SCRIPTS_AUTO_ANSWER=y ~/Code/Personal/scripts/run-set-up-scripts
```

## Remove Dirs to Reset Chezmoi State

```shell
rm -rf ~/.config/chezmoi ~/.local/share/chezmoi
```
