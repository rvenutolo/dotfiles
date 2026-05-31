#!/usr/bin/env bash

# Sourced from bashrc.bash in interactive shells only (after env.bash).
# Bash UX: shopt, history, completions, prompt, aliases. Uses the
# __executable_exists / __is_readable_file / __path_* helpers defined in
# env.bash; unsets them at the end of this file.

# system bash config files to source
for file in '/etc/bash.bashrc' '/etc/bashrc'; do
  if [[ -r "${file}" ]]; then
    source "${file}"
  fi
done
unset -v file

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

# history
export HISTCONTROL='ignorespace:ignoredups'
export HISTIGNORE='ls:ll:lla:pwd:bg:fg:history:h:exit:q:pwd:clear:cls:update:brc:dl:home:c'
export HISTSIZE='100000'
export HISTFILESIZE="${HISTSIZE}"
export HISTTIMEFORMAT='%F %T%t'
export HISTFILE="${XDG_STATE_HOME}/bash/history"
if [[ ! -d "$(dirname "${HISTFILE}")" ]]; then
  mkdir --parents "$(dirname "${HISTFILE}")"
fi

# app files to source
for file in \
  '/usr/share/doc/pkgfile/command-not-found.bash' \
  '/usr/share/fzf/key-bindings.bash' \
  "${XDG_CONFIG_HOME}/broot/launcher/bash/br"; do
  if __is_readable_file "${file}"; then
    source "${file}"
  fi
done
unset -v file

# Re-source SDKMAN init with completion enabled. non-interactive.bash
# sourced it with sdkman_auto_complete=false to skip the `complete` call
# (which errors in non-interactive shells). Re-sourcing here, with the
# default (true), adds the `sdk` completion. PATH and the `sdk` function
# are idempotent under a second source.
if __is_readable_file "${SDKMAN_DIR}/bin/sdkman-init.sh"; then
  source "${SDKMAN_DIR}/bin/sdkman-init.sh"
fi

# completions to source
for file in \
  '/usr/share/bash-completion/bash_completion' \
  '/usr/share/bash/bash-completion/completions/'* \
  '/usr/share/fzf/completion.bash' \
  '/usr/share/git/completion/git-completion.bash' \
  '/usr/share/skim/completion.bash' \
  '/usr/share/the_silver_searcher/completions/ag.bashcomp.sh' \
  '/etc/bash_completion' \
  "${SDKMAN_DIR}/candidates/mvnd/current/bin/mvnd-bash-completion.bash" \
  "${SDKMAN_DIR}/candidates/springboot/current/shell-completion/bash/spring"; do
  if __is_readable_file "${file}"; then
    source "${file}"
  fi
done
unset -v file

# my files to source
for file in \
  "${XDG_CONFIG_HOME}/bash/functions.bash" \
  "${XDG_CONFIG_HOME}/bash/aliases.bash" \
  "${XDG_CONFIG_HOME}/bash/local.bash"; do
  if __is_readable_file "${file}"; then
    source "${file}"
  fi
done
unset -v file

# misc init stuff
__is_readable_file "${XDG_CONFIG_HOME}/dircolors" && eval "$(dircolors "${XDG_CONFIG_HOME}/dircolors")"
__executable_exists 'aws_completer' && complete -C 'aws_completer' aws
__executable_exists 'appman' && complete -W "$(cat "${XDG_DATA_HOME}/appman/appman/list" 2> /dev/null)" appman
__executable_exists 'carapace' && source <(carapace _carapace)
__executable_exists 'batpipe' && eval "$(batpipe)"
__executable_exists 'kubectl' && source <(kubectl completion bash)
__executable_exists 'zoxide' && export _ZO_DOCTOR='0' && eval "$(zoxide init bash)"

# add completions for aliases
# sourced here, rather than earlier, to make sure all aliases and bash completions have been sourced
if __is_readable_file "${XDG_CONFIG_HOME}/bash/complete_alias.bash"; then
  source "${XDG_CONFIG_HOME}/bash/complete_alias.bash"
  complete -F _complete_alias "${!BASH_ALIASES[@]}"
fi

__executable_exists 'direnv' && eval "$(direnv hook bash)"

# put this last as starship_preexec() will run before every command after this
__executable_exists 'starship' && eval "$(starship init bash)"

# clean up helper functions (defined in env.bash)
unset -f __executable_exists __is_readable_file __path_append __path_prepend __path_remove
