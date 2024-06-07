# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Install & Init

```shell
adduser --ingroup 'sudo' 'rvenutolo' && su - 'rvenutolo'
sh -c "$(curl -fsLS 'get.chezmoi.io')" -- -b '/tmp' ## OR sh -c "$(wget -qO- 'get.chezmoi.io')" -- -b '/tmp'
/tmp/chezmoi init --apply 'rvenutolo'
source ~/.bash_profile
~/Code/Personal/scripts/run-install-scripts
~/Code/Personal/scripts/run-set-up-scripts
```

## Remove relevant directories

```shell
rm -rf ~/.cache/etags ~/.config/chezmoi ~/.keys ~/.local/share/chezmoi
```
