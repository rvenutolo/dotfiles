# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

```shell
$ sh -c "$(curl -fsLS 'get.chezmoi.io')" -- -b '.' \
  && ./chezmoi init --apply 'rvenutolo'
  && source '~/.bashrc'
```
