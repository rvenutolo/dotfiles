# chezmoi-dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

```shell
$ sh -c "$(curl -fsLS 'get.chezmoi.io')" -- -b '.' \
  && ./chezmoi init 'rvenutolo' \
  && ./chezmoi apply
```

Note: When doing `chezmoi init --apply`, the env vars defined in the chezmoi
config file are not set when the `.chezmoiscripts` scripts are run. So run
`init` and `apply` separately to work around this.
