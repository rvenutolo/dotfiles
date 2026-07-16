#!/usr/bin/env bash

# Sourced from bashrc.bash in interactive shells only. Bash UX: shopt,
# history, completions, prompt, aliases. Helper functions are defined at
# the top of this file and unset at the bottom.

# PATH manipulation helpers (sourced once; unset at the bottom of this
# file).
if [[ -r "${XDG_CONFIG_HOME}/path-helpers.sh" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${XDG_CONFIG_HOME}/path-helpers.sh"
fi

# system bash config files to source
for file in '/etc/bash.bashrc' '/etc/bashrc'; do
  if [[ -r "${file}" ]]; then
    # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
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
  if [[ -r "${file}" ]]; then
    # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
    source "${file}"
  fi
done
unset -v file

# Re-source SDKMAN init with completion enabled. non-interactive.bash
# sourced it with sdkman_auto_complete=false to skip the `complete` call
# (which errors in non-interactive shells). Re-sourcing here, with the
# default (true), adds the `sdk` completion. PATH and the `sdk` function
# are idempotent under a second source.
if [[ -r "${SDKMAN_DIR}/bin/sdkman-init.sh" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
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
  if [[ -r "${file}" ]]; then
    # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
    source "${file}"
  fi
done
unset -v file

# my files to source
for file in \
  "${XDG_CONFIG_HOME}/bash/functions.bash" \
  "${XDG_CONFIG_HOME}/bash/aliases.bash" \
  "${XDG_CONFIG_HOME}/bash/local.bash"; do
  if [[ -r "${file}" ]]; then
    # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
    source "${file}"
  fi
done
unset -v file

path_prepend "${SCRIPTS_DIR}/interactive"

# misc init stuff
[[ -r "${XDG_CONFIG_HOME}/dircolors" ]] && eval "$(dircolors "${XDG_CONFIG_HOME}/dircolors")"
command -v 'aws_completer' > /dev/null 2>&1 && complete -C 'aws_completer' aws
command -v 'appman' > /dev/null 2>&1 && complete -W "$(cat "${XDG_DATA_HOME}/appman/appman/list" 2> /dev/null)" appman
# shellcheck disable=SC1090  # completions generated at runtime; no file to follow
command -v 'carapace' > /dev/null 2>&1 && source <(carapace _carapace)
command -v 'batpipe' > /dev/null 2>&1 && eval "$(batpipe)"
# shellcheck disable=SC1090  # completions generated at runtime; no file to follow
command -v 'kubectl' > /dev/null 2>&1 && source <(kubectl completion bash)
command -v 'zoxide' > /dev/null 2>&1 && export _ZO_DOCTOR='0' && eval "$(zoxide init bash)"

# add completions for aliases
# sourced here, rather than earlier, to make sure all aliases and bash completions have been sourced
if [[ -r "${XDG_CONFIG_HOME}/bash/complete_alias.bash" ]]; then
  # shellcheck source=/dev/null  # sourced at runtime; path not statically resolvable
  source "${XDG_CONFIG_HOME}/bash/complete_alias.bash"
  complete -F _complete_alias "${!BASH_ALIASES[@]}"
fi

command -v 'direnv' > /dev/null 2>&1 && eval "$(direnv hook bash)"

# put this last as starship_preexec() will run before every command after this
command -v 'starship' > /dev/null 2>&1 && eval "$(starship init bash)"

# clean up helper functions
path_helpers_unset
