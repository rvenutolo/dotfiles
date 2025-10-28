#!/usr/bin/env sh

__executable_exists() {
  command -v "$1" > /dev/null 2>&1
}
__is_readable_file() {
  [ -r "$1" ]
}
__path_remove() {
  PATH=$(printf '%s\n' "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"$1"'"' | sed 's/:$//')
}
__path_append() {
  __path_remove "$1" && PATH="$PATH:$1"
}
__path_prepend() {
  __path_remove "$1" && PATH="$1:$PATH"
}

umask 022

# xdg base dirs - https://wiki.archlinux.org/title/XDG_Base_Directory
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_DATA_HOME="${HOME}/.local/share"
export XDG_STATE_HOME="${HOME}/.local/state"
export XDG_DATA_DIRS="${XDG_DATA_DIRS:-}"
export XDG_DATA_DIRS="/var/lib/flatpak/exports/share:${XDG_DATA_DIRS}"
export XDG_DATA_DIRS="${HOME}/.local/share/flatpak/exports/share:${XDG_DATA_DIRS}"
export XDG_DATA_DIRS="${HOME}/.nix-profile/share:${XDG_DATA_DIRS}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id --user)}"

# personal env vars
export PERSONAL_DESKTOP_HOSTNAME='redstar'
export PERSONAL_LAPTOP_HOSTNAME='bluestar'
export WORK_LAPTOP_HOSTNAME='silverstar'
export CODE_DIR="${HOME}/Code"
export SCRIPTS_DIR="${CODE_DIR}/Personal/scripts"
export HOME_MANAGER_DIR="${XDG_CONFIG_HOME}/home-manager"
export HOME_MANAGER_PACKAGES_FILE="${HOME_MANAGER_DIR}/packages.nix"
export PACKAGES_DIR="${CODE_DIR}/Personal/packages"
export WTTR_CITY='Atlanta'

# age / crypt
export AGE_PUBLIC_KEY='age1v9umzaqlw3euuwd20l605qeyqp9cmqxf3flzz0eh9gj5vxslsarq6fy8gs'
export AGE_PRIVATE_KEY_FILE="${HOME}/.keys/age.key"
export CRYPT_DIR="${HOME}/.crypt"

## dirs and files
export ANDROID_HOME="${XDG_DATA_HOME}/android"
export ATOM_HOME="${XDG_DATA_HOME}/atom"
export AWS_CONFIG_FILE="${XDG_CONFIG_HOME}/aws/config"
export AWS_SHARED_CREDENTIALS_FILE="${XDG_CONFIG_HOME}/aws/credentials"
export CARGO_HOME="${XDG_DATA_HOME}/cargo"
export DOCKER_CONFIG="${XDG_CONFIG_HOME}/docker"
export FFMPEG_DATADIR="${XDG_CONFIG_HOME}/ffmpeg"
export GEM_HOME="${XDG_DATA_HOME}/gem"
export GEM_SPEC_CACHE="${XDG_CACHE_HOME}/gem"
export GNUPGHOME="${XDG_DATA_HOME}/gnupg"
export GOBIN="${HOME}/.go/bin"
export GOCACHE="${XDG_CACHE_HOME}/go-build"
export GOMODCACHE="${XDG_CACHE_HOME}/go/mod"
export GOPATH="${HOME}/.go"
export GRADLE_USER_HOME="${XDG_DATA_HOME}/gradle"
export GTK2_RC_FILES="${XDG_CONFIG_HOME}/gtk-2.0/gtkrc"
export INPUTRC="${XDG_CONFIG_HOME}/readline/inputrc"
export KDEHOME="${XDG_CONFIG_HOME}/kde"
export LESSHISTFILE="${XDG_STATE_HOME}/less/history"
export NPM_CONFIG_USERCONFIG="${XDG_CONFIG_HOME}/npm/npmrc"
export PARALLEL_HOME="${XDG_CONFIG_HOME}/parallel"
export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/config"
export RUSTUP_HOME="${XDG_DATA_HOME}/rustup"
export SDKMAN_DIR="${HOME}/.sdkman"
export SCREENRC="${XDG_CONFIG_HOME}/screen/screenrc"
export SDKMAN_DIR="${XDG_DATA_HOME}/sdkman"
export SONARLINT_USER_HOME="${XDG_DATA_HOME}/sonarlint"
export STACK_ROOT="${XDG_DATA_HOME}/stack"
export STARSHIP_CACHE="${XDG_CACHE_HOME}/starship"
export TERMINFO="${XDG_DATA_HOME}/terminfo"
export TERMINFO_DIRS="${XDG_DATA_HOME}/terminfo:/usr/share/terminfo"
export WGETRC="${XDG_CONFIG_HOME}/wgetrc"

## misc
export DIFFPROG='meld'
export GPG_TTY="$(tty)"
export HSTR_CONFIG='hicolor'
export MAVEN_OPTS='-Xms256m -Xmx1g'
export NIXPKGS_ALLOW_UNFREE='1'
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR}/ssh-agent.socket"
export STACK_XDG='1'
export SYSTEMD_PAGER=''

## editor/visual
if __executable_exists 'micro'; then
  export EDITOR='micro'
elif __executable_exists 'nano'; then
  export EDITOR='nano'
elif __executable_exists 'nvim'; then
  export EDITOR='nvim'
else
  export EDITOR='vim'
fi
if __executable_exists 'kate'; then
  export VISUAL='kate'
else
  export VISUAL="${EDITOR}"
fi

# pager
if __executable_exists 'moor'; then
  export PAGER='moor'
else
  export PAGER='less --ignore-case'
fi
export MANPAGER="${PAGER}"
export GROFF_NO_SGR=1

# file manager
case "${XDG_CURRENT_DESKTOP:-}" in
  KDE) export FILE_MANAGER='dolphin' ;;
  *GNOME) export FILE_MANAGER='nautilus' ;;
  *) export FILE_MANAGER='ranger' ;;
esac

## less
LESS_TERMCAP_mb=$(tput -T ansi blink) # start blink
LESS_TERMCAP_md=$(tput -T ansi setaf 2 ; tput -T ansi bold) # start bold
LESS_TERMCAP_me=$(tput -T ansi sgr0)  # turn off bold, blink and underline
LESS_TERMCAP_so=$(tput -T ansi smso)  # start standout (reverse video)
LESS_TERMCAP_se=$(tput -T ansi rmso)  # stop standout
LESS_TERMCAP_us=$(tput -T ansi smul)  # start underline
LESS_TERMCAP_ue=$(tput -T ansi rmul)  # stop underline
export LESS_TERMCAP_mb
export LESS_TERMCAP_md
export LESS_TERMCAP_me
export LESS_TERMCAP_se
export LESS_TERMCAP_so
export LESS_TERMCAP_ue
export LESS_TERMCAP_us

## tailscale
if __executable_exists 'tailscale' && tailscale status > '/dev/null' ; then
  export TAILNET_IP="$(tailscale ip -4)"
  export TAILNET_CIDR='100.64.0.0/10'
fi

## this addresses when ssh-ing to a box that doesn't have terminfo for whatever TERM currently is
for TERM in "${TERM}" 'xterm-256color' 'xterm-16color' 'xterm-color' 'xterm'; do
  if infocmp -0 > /dev/null 2>&1; then
    break
  fi
done

for dir in \
  '/bin' \
  '/sbin' \
  '/usr/bin' \
  '/usr/sbin' \
  '/usr/local/bin' \
  '/usr/local/sbin' \
  "${HOME}/.nix-profile/bin" \
  "${HOME}/.local/share/JetBrains/Toolbox/scripts" \
  "${HOME}/.local/bin" \
  "${HOME}/.bin"; do
  __path_prepend "${dir}"
done
unset -v dir

if __is_readable_file "${HOME}/.profile-local";  then
  . "${HOME}/.profile-local"
fi

unset -f __executable_exists __is_readable_file __path_append __path_prepend __path_remove
