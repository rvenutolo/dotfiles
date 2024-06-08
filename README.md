# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Install & Init

```shell
adduser --ingroup 'sudo' 'rvenutolo' && su - 'rvenutolo'
sh -c "$(curl -fsLS 'get.chezmoi.io')" -- -b '/tmp' ## OR sh -c "$(wget -qO- 'get.chezmoi.io')" -- -b '/tmp'
SCRIPTS_AUTO_ANSWER='y' /tmp/chezmoi init --apply 'rvenutolo'
SCRIPTS_AUTO_ANSWER='y' ~/Code/Personal/scripts/run-install-scripts
SCRIPTS_AUTO_ANSWER='y' ~/Code/Personal/scripts/run-set-up-scripts
```

## Remove Misc Dirs to Reset State 

```shell
rm -rf ~/.cache/etags ~/.config/chezmoi ~/.keys ~/.local/share/chezmoi
```
