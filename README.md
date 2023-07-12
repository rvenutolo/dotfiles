# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Preparation

### Arch

```shell
sudo pacman --sync --refresh --needed --noconfirm age git openssh
```

### Fedora

```shell
sudo dnf install --assumeyes age git openssh
```

### Ubuntu

```shell
sudo apt install --assume-yes age git openssh-client
```

## Chezmoi

```shell
$ sh -c "$(curl -fsLS 'get.chezmoi.io')" -- -b '.' ## OR sh -c "$(wget -qO- 'get.chezmoi.io')" -- -b '.'
$ ./chezmoi init --apply 'rvenutolo'
```
