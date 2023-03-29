#!/usr/bin/env bash

# if not running interactively, don't do anything
[[ "$-" != *i* ]] && return

umask 022
ulimit -S -c 0 # no core dumps
set -o notify
set -o noclobber
set -o ignoreeof
unalias -a

# shopt -p | sort -k3
shopt -u assoc_expand_once
shopt -s autocd
shopt -u cdable_vars
shopt -s cdspell
shopt -s checkhash
shopt -s checkjobs
shopt -s checkwinsize
shopt -s cmdhist
shopt -u compat31
shopt -u compat32
shopt -u compat40
shopt -u compat41
shopt -u compat42
shopt -u compat43
shopt -u compat44
shopt -s complete_fullquote
shopt -s direxpand
shopt -s dirspell
shopt -s dotglob
shopt -u execfail
shopt -s expand_aliases
shopt -u extdebug
shopt -s extglob
shopt -s extquote
shopt -u failglob
shopt -s force_fignore
shopt -s globasciiranges
shopt -s globstar
shopt -u gnu_errfmt
shopt -s histappend
shopt -u histreedit
shopt -u histverify
shopt -u hostcomplete
shopt -u huponexit
shopt -u inherit_errexit
shopt -s interactive_comments
shopt -u lastpipe
shopt -u lithist
shopt -u localvar_inherit
shopt -u localvar_unset
shopt -u login_shell
shopt -u mailwarn
shopt -s nocaseglob
shopt -u nocasematch
shopt -s no_empty_cmd_completion
shopt -u nullglob
shopt -s progcomp
shopt -s progcomp_alias
shopt -s promptvars
shopt -u restricted_shell
shopt -u shift_verbose
shopt -s sourcepath
shopt -u xpg_echo

# functions used in my bash config files
function __executable_exists() {
  type -aPf "$1" > /dev/null 2>&1
}
function __is_readable_file() {
  [[ -f "$1" && -r "$1" ]]
}
function __path_remove() {
  PATH=$(echo -n "$PATH" | awk -v RS=: -v ORS=: '$0 != "'"$1"'"' | sed 's/:$//')
}
function __path_append() {
  __path_remove "$1" && PATH="$PATH:$1"
}
function __path_prepend() {
  __path_remove "$1" && PATH="$1:$PATH"
}

# archlinux sourcing
# /etc/profile
# -- add to path /usr/local/sbin /usr/local/bin /usr/bin
# -- source /etc/profile.d/*.sh (bunch of program-specific stuff)
# -- source /etc/bash.bashrc
#   -- sets PROMPT_COMMAND based on TERM
#   -- source /usr/share/bash-completion/bash_completion
#     -- source /etc/bash_completion.d/*
#     -- source ~/.bash_completion

# debian sourcing
# /etc/profile
# -- add to path /usr/local/bin /usr/bin /bin /usr/local/games /usr/games
# -- source /etc/bash.bashrc
#   -- (commented out) source /usr/share/bash-completion/bash_completion OR /etc/bash_completion
# -- source /etc/profile.d/*.sh (bunch of program-specific stuff)

# fedora sourcing
# /etc/profile
# -- add to path /usr/local/sbin /usr/sbin
# -- source etc/profile.d/*.sh (bunch of program-specific stuff)
# -- source /etc/bashrc
#   -- sets PROMPT_COMMAND based on TERM
#   -- source etc/profile.d/*.sh (bunch of program-specific stuff)

# ubuntu sourcing
# /etc/environment
# -- add to path /usr/local/sbin /usr/local/bin /usr/sbin /usr/bin /sbin /bin /usr/games /usr/local/games /snap/bin
# /etc/profile
# -- source /etc/bash.bashrc
#   -- (commented out) source /usr/share/bash-completion/bash_completion OR /etc/bash_completion
# -- source /etc/profile.d/*.sh (bunch of program-specific stuff)

# my files to source
for file in \
  "${XDG_CONFIG_HOME}/bash/functions.bash" \
  "${XDG_CONFIG_HOME}/bash/exports.bash" \
  "${XDG_CONFIG_HOME}/bash/aliases.bash" \
  "${XDG_CONFIG_HOME}/bash/local.bash"; do
  if __is_readable_file "${file}"; then
    source "${file}"
  fi
done

# app files to source
for file in \
  '/usr/share/fzf/key-bindings.bash' \
  "${SDKMAN_DIR}/bin/sdkman-init.sh" \
  "${XDG_CONFIG_HOME}/broot/launcher/bash/br"; do
  if __is_readable_file "${file}"; then
    ## TODO look into addressing sdkman unbound variables
    source "${file}"
  fi
done

# completions to source
for file in \
  '/usr/share/bash/bash-completion/completions/'* \
  '/usr/share/fzf/completion.bash' \
  '/usr/share/git/completion/git-completion.bash' \
  '/usr/share/skim/completion.bash' \
  '/usr/share/the_silver_searcher/completions/ag.bashcomp.sh' \
  "${SDKMAN_DIR}/candidates/mvnd/current/bin/mvnd-bash-completion.bash" \
  "${SDKMAN_DIR}/candidates/springboot/current/shell-completion/bash/spring"; do
  if __is_readable_file "${file}"; then
    ## TODO look into addressing sdkman unbound variables
    source "${file}"
  fi
done

# dirs to put on path
for dir in \
  "$(if __executable_exists 'ruby'; then echo "$(ruby -e 'puts Gem.user_dir')/bin"; else echo ''; fi)" \
  "$(if __executable_exists 'go'; then echo "$(go env GOPATH)/bin"; else echo ''; fi)" \
  "$(if [[ -n "${CARGO_HOME}" ]]; then echo "${CARGO_HOME}/bin"; else echo ''; fi)" \
  "${HOME}/.local/bin" \
  "${SCRIPTS_DIR}/other" \
  "${SCRIPTS_DIR}/main"; do
  if [[ -n "${dir}" && -d "${dir}" ]]; then
    __path_prepend "${dir}"
  fi
done

# create dirs that may not exist (need to use `command` because `mkdir` is aliased)
command mkdir --parents "$(dirname "${HISTFILE}")"

# misc init stuff
__is_readable_file "${XDG_CONFIG_HOME}/dircolors" && eval "$(dircolors "${XDG_CONFIG_HOME}/dircolors")"
__executable_exists 'aws_completer' && complete -C 'aws_completer' aws
## TODO re-enable zoxide
#__executable_exists 'zoxide' && eval "$(zoxide init bash)"

# add completions for aliases
# sourced here, rather than earlier, to make sure all aliases and bash completions have been sourced
if __is_readable_file "${XDG_CONFIG_HOME}/bash/complete_alias.bash"; then
  source "${XDG_CONFIG_HOME}/bash/complete_alias.bash"
  complete -F _complete_alias "${!BASH_ALIASES[@]}"
fi

## TODO submit PR to address unbound variables?
## TODO re-enable starship
#STARSHIP_PREEXEC_READY=false
# put this after resetting shell options as starship_preexec() will run before
# every command after this
#__executable_exists 'starship' && eval "$(starship init bash)"
if __is_readable_file "${XDG_CONFIG_HOME}/bash/prompt.bash"; then
  source "${XDG_CONFIG_HOME}/bash/prompt.bash"
fi

# clean up vars & functions
unset -v file dir shell_option initial_shell_options initial_pipefail_option
unset -f __executable_exists __is_readable_file __path_append __path_prepend __path_remove