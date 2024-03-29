#!/usr/bin/env bash

# +-----------------+
# + Git Integration +
# +-----------------+
# +--- Dirty State ---+
# Show unstaged (*) and staged (+) changes.
# Also configurable per repository via "bash.showDirtyState".
export GIT_PS1_SHOWDIRTYSTATE=true

# +--- Stash State ---+
# Show currently stashed ($) changes.
export GIT_PS1_SHOWSTASHSTATE=true

# +--- Untracked Files ---+
# Show untracked (%) changes.
# Also configurable per repository via "bash.showUntrackedFiles".
export GIT_PS1_SHOWUNTRACKEDFILES=true

# +--- Upstream Difference ---+
# Show indicator for difference between HEAD and its upstream.
#
# <  Behind upstream
# >  Ahead upstream
# <> Diverged upstream
# =  Equal upstream
#
# Control behaviour by setting to a space-separated list of values:
#   auto     Automatically show indicators
#   verbose  Show number of commits ahead/behind (+/-) upstream
#   name     If verbose, then also show the upstream abbrev name
#   legacy   Do not use the '--count' option available in recent versions of git-rev-list
#   git      Always compare HEAD to @{upstream}
#   svn      Always compare HEAD to your SVN upstream
#
# By default, __git_ps1 will compare HEAD to SVN upstream ('@{upstream}' if not available).
# Also configurable per repository via "bash.showUpstream".
export GIT_PS1_SHOWUPSTREAM=""

# +--- Describe Style ---+
# Show more information about the identity of commits checked out as a detached HEAD.
#
# Control behaviour by setting to one of these values:
#   contains  Relative to newer annotated tag (v1.6.3.2~35)
#   branch    Relative to newer tag or branch (master~4)
#   describe  Relative to older annotated tag (v1.6.3.1-13-gdd42c2f)
#   default   Exactly matching tag
export GIT_PS1_DESCRIBE_STYLE="contains"

# +--- Colored Hints ---+
# Show colored hints about the current dirty state. The colors are based on the colored output of "git status -sb".
# NOTE: Only available when using __git_ps1 for PROMPT_COMMAND!
export GIT_PS1_SHOWCOLORHINTS=false

# +--- pwd Ignore ---+
# Disable __git_ps1 output when the current directory is set up to be ignored by git.
# Also configurable per repository via "bash.hideIfPwdIgnored".
export GIT_PS1_HIDE_IF_PWD_IGNORED=false

function __prompt_timer_now() {
  date '+%s%3N'
}

function __prompt_timer_start() {
  [[ -z "${__prompt_timer-}" ]] && __prompt_timer="$(__prompt_timer_now)"
}

function __prompt_timer_stop() {
  local total_ms=$(("$(__prompt_timer_now)" - "${__prompt_timer}"))
  local total_s=$((total_ms / 1000))
  local ms=$((total_ms % 1000))
  local s=$((total_s % 60))
  local m=$(((total_s / 60) % 60))
  local h=$((total_s / 3600))
  if ((h > 0)); then
    __prompt_timer_string="${h}h${m}m"
  elif ((m > 0)); then
    __prompt_timer_string="${m}m${s}s"
  elif ((s > 0)); then
    __prompt_timer_string="${s}s${ms}ms"
  else
    __prompt_timer_string="${ms}ms"
  fi
  unset __prompt_timer
}

__prompt_command() {

  local exit_code="$?"

  __prompt_timer_stop

  local regular_black='\[\e[0;30m\]'
  local regular_red='\[\e[0;31m\]'
  local regular_green='\[\e[0;32m\]'
  local regular_yellow='\[\e[0;33m\]'
  local regular_blue='\[\e[0;34m\]'
  local regular_purple='\[\e[0;35m\]'
  local regular_cyan='\[\e[0;36m\]'
  local regular_white='\[\e[0;37m\]'
  local bold_black='\[\e[1;30m\]'
  local bold_red='\[\e[1;31m\]'
  local bold_green='\[\e[1;32m\]'
  local bold_yellow='\[\e[1;33m\]'
  local bold_blue='\[\e[1;34m\]'
  local bold_purple='\[\e[1;35m\]'
  local bold_cyan='\[\e[1;36m\]'
  local bold_white='\[\e[1;37m\]'
  local underline_black='\[\e[4;30m\]'
  local underline_red='\[\e[4;31m\]'
  local underline_green='\[\e[4;32m\]'
  local underline_yellow='\[\e[4;33m\]'
  local underline_blue='\[\e[4;34m\]'
  local underline_purple='\[\e[4;35m\]'
  local underline_cyan='\[\e[4;36m\]'
  local underline_white='\[\e[4;37m\]'
  local background_black='\[\e[40m\]'
  local background_red='\[\e[41m\]'
  local background_green='\[\e[42m\]'
  local background_yellow='\[\e[43m\]'
  local background_blue='\[\e[44m\]'
  local background_purple='\[\e[45m\]'
  local background_cyan='\[\e[46m\]'
  local background_white='\[\e[47m\]'
  local regular_reset='\[\e[0m\]'
  local reset='\[\e[0m\]'

  local nonzero_color="${bold_red}"
  local user_color="${bold_blue}"
  local at_color="${bold_white}"
  local host_color="${bold_blue}"
  local arrow_color="${bold_white}"
  local dir_color="${bold_cyan}"
  local branch_icon_color="${bold_white}"
  local branch_color="${bold_blue}"
  local timestamp_color="${bold_cyan}"
  local last_command_time_color="${bold_cyan}"
  local prompt_color="${bold_white}"
  if [[ "${USER}" == 'root' ]]; then
    user_color="${bold_red}"
  fi

  local nonzero_exit="${nonzero_color}Non-zero exit code: ${exit_code}"
  local user="${user_color}\u"
  local at="${at_color}@"
  local host="${host_color}\h"
  local arrow="${arrow_color}→"
  local dir="${dir_color}\w"
  export GIT_PS1_STATESEPARATOR='|'
  local git_status="\$(declare -f -F '__git_ps1' >/dev/null 2>&1 && __git_ps1 '${branch_icon_color}${branch_color}%s${reset}')"
  local timestamp="${timestamp_color}\D{%I:%M:%S}"
  local last_command_time="${last_command_time_color}${__prompt_timer_string}"
  local prompt="${prompt_color}\\$"

  # Glue the prompt to always go to the first column (http://jonisalonen.com/2012/your-bash-prompt-needs-this/)
  PS1="\[\033[G\]"
  if [[ "$exit_code" != 0 ]]; then
    PS1+="${nonzero_exit}\n"
  fi
  PS1+="${bold_white}["
  PS1+="${timestamp}"
  PS1+="${bold_white}|"
  PS1+="${last_command_time}"
  PS1+="${bold_white}|"
  if [[ -n "${SSH_CONNECTION:-}" ]] || [[ "${USER}" == 'root' ]] || [[ "${LOGNAME}" != "${USER}" ]]; then
    PS1+="${user}${at}${host}:"
  fi
  PS1+="${dir}${git_status}"
  PS1+="${bold_white}]"
  PS1+="\n"
  PS1+="${prompt} "
  PS1+="${reset}"

  PS2=""
  PS2+="  ${arrow} "
  PS2+="${reset}"

}

trap '__prompt_timer_start' DEBUG
PROMPT_COMMAND=__prompt_command;printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#${HOME}/\~}"
