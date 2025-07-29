#!/usr/bin/env bash

# sudo
alias sudo='sudo '
alias sued='sudo --edit'
alias please='sudo $(fc -ln -1)'
alias plz='please'

# cd
alias cd..='cd ..'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias .1='cd ..'
alias .2='cd ../..'
alias .3='cd ../../..'
alias .4='cd ../../..'
alias .5='cd ../../../..'
alias .6='cd ../../../../..'
alias -- -='cd -'
alias home='cl ${HOME}'
alias dl='cl ${HOME}/Downloads'
alias dt='cl ${HOME}/Desktop'
alias c='cl ${CODE_DIR}'
alias s='cl ${SCRIPTS_DIR}'
alias d='cl ${CODE_DIR}/Personal/dotfiles'
alias p='cl ${PACKAGES_DIR}'
alias bd='cd "$OLDPWD"'

# ls
if __executable_exists 'exa'; then
  alias exa='exa --classify --group-directories-first --icons --header --time-style=long-iso --color-scale --git'
  alias ls='exa'
  alias l='exa'
  alias ll='exa --long'
  alias la='exa --all'
  alias lla='exa --long --all'
  alias llx='exa --long --sort=extension'
  alias llax='exa --long --all --sort=extension'
  alias lls='exa --long --sort=size'
  alias llas='exa --long --all --sort=size'
  alias llc='exa --long --sort=mod'
  alias llac='exa --long --all --sort=mod'
  alias llr='exa --long --recurse'
  alias llar='exa --long --all --recurse'
  alias l1='exa --oneline'
  alias la1='exa --all --oneline'
  alias ltree='exa --long --tree'
else
  alias ls='ls --classify --human-readable --color --group-directories-first'
  alias l='ls'
  alias ll='ls -l'
  alias la='ls --almost-all'
  alias lla='ls -l --almost-all'
  alias llx='ls -lX' # sort by extension
  alias llax='ls -lX --almost-all'
  alias lls='ls -lS --reverse' # sort by size, biggest last
  alias llas='ls -lS --almost-all --reverse'
  alias llc='ls -ltc --reverse' # sort by and show change time, most recent last
  alias llac='ls -ltc --almost-all --reverse'
  alias llr='ls -l --recursive' # recursive ls
  alias llar='ls -l --almost-all --recursive'
  alias l1='ls -1'
  alias la1='ls --almost-all -1'
fi

# cp, mv, rm, mkdir, trash
alias mkdir='mkdir --parents --verbose'
alias cp='cp --verbose'
alias mv='mv --verbose'
alias rm='rm -i --verbose'

# chown, chmod, chgrp
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chax='chmod a+x'
alias chux='chmod u+x'
alias 600='chmod --recursive 600'
alias 640='chmod --recursive 640'
alias 644='chmod --recursive 644'
alias 655='chmod --recursive 655'
alias 700='chmod --recursive 700'
alias 744='chmod --recursive 744'
alias 755='chmod --recursive 755'
alias 775='chmod --recursive 775'
alias chgrp='chgrp --preserve-root'

# grep
alias grep="grep --exclude-dir='.*' --colour=auto"
alias egrep='grep --extended-regexp'
alias fgrep='grep --fixed-strings'

# tar
alias mktar='tar --create --verbose --file'
alias mkbz2='tar --create --verbose --bzip2 --file'
alias mkgz='tar --create --verbose --gzip --file'
alias untar='tar --extract --verbose --file'
alias unbz2='tar --extract --verbose --bzip2 --file'
alias ungz='tar --extract --verbose --gzip --file'

# ps
alias psa='ps aux'
alias psaf='ps auxf'

# journalctl, systemctl
alias jc='journalctl'
alias jce='jounralctl --priority=3'
alias sc='systemctl'
alias scu='systemctl --user'

# editors
alias k='kate'
alias m='micro'
alias n='nano'

# nix home-manager
if __executable_exists 'home-manager'; then
  alias hm='home-manager'
  alias hmd='cd "${HOME_MANAGER_DIR}"'
  alias hmp='home-manager-packages'
  alias hmu='home-manager-update'
  alias hms='home-manager-switch'
  alias hmn='home-manager news'
  alias hmgd='home-manager-generations-diff'
fi

# docker
if __executable_exists 'docker'; then
  alias dc='docker compose'
  alias dcu='docker-compose-up'
  alias dcd='docker-compose-down'
  alias dcl='docker-compose-logs'
  alias dcp='docker-compose-pull'
  alias dcps='docker-compose-ps'
  alias dcr='docker-compose-restart'
fi

# misc - shorter alias
alias g='git'
alias o='xdg-open'
alias q='exit'
alias h='history'
alias t='tldr'
alias am='appman'
alias cm='chezmoi'
alias ff='fastfetch'
alias hh='hstr'
alias ms='manswitch'
alias ns='new-script'
alias cls='clear'
alias sup='sync-universal-packages'
alias sshh='ssh-host-selector'

# misc - adds flags
alias curl="curl --write-out '\n'"
alias type='type -a'
alias du='du --total --summarize --si'
alias df='df --print-type --si --exclude-type squashfs --exclude-type tmpfs --exclude-type devtmpfs'
alias free='free --total --human --si'
alias br='br --dates --hidden --permissions'
alias ln='ln --verbose'
alias jobs='jobs -l'
alias tree='tree -Cph --si'
alias shfmt='shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write'
alias xdg-ninja='xdg-ninja --skip-unsupported'

# misc - other
alias bs='br --sizes'
alias da="date '+%Y-%m-%d %A %T %Z'"
alias du1='du --max-depth=1'
alias hg='history | grep'
alias sbp='source ${HOME}/.bash_profile'
if [[ -n "${SDKMAN_DIR}" && -f "${SDKMAN_DIR}/candidates/maven/current/bin/mvn" ]]; then
  alias sdkmvn='${SDKMAN_DIR}/candidates/maven/current/bin/mvn'
fi
