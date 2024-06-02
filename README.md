# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Install & Init

```shell
$ sh -c "$(curl -fsLS 'get.chezmoi.io')" -- -b '/tmp' ## OR sh -c "$(wget -qO- 'get.chezmoi.io')" -- -b '/tmp'
$ /tmp/chezmoi init --apply 'rvenutolo'
$ source ~/.bash_profile
```

## Remove chezmoi directories

```shell
rm -rf ~/.local/share/chezmoi ~/.config/chezmoi
```
