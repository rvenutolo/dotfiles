# dotfiles

Dotfiles managed by [chezmoi](https://www.chezmoi.io/).

## Preparation

### Arch

```shell
sudo pacman --sync --refresh --needed --noconfirm age bash-completion git openssh
```

### Fedora

```shell
sudo dnf install --assumeyes age bash-completion git openssh
```

### Ubuntu

```shell
sudo apt install --assume-yes --install-recommends --install-suggests age bash-completion git openssh-client
```

## Chezmoi

```shell
$ sh -c "$(curl -fsLS 'get.chezmoi.io')" -- -b '.' ## OR sh -c "$(wget -qO 'get.chezmoi.io')" -- -b '.'
$ ./chezmoi init --apply 'rvenutolo'
```
