#!/bin/zsh

CONFIG="${HOME}/.screenrc"
alias screenini="git config -f ${CONFIG}"

screen () {
  local OVERRIDE=$(screenini --bool "screen.override")
  if [[ ${OVERRIDE} == true ]]; then
    local screenname="screen"

    if [[ -n "${TMUX}" ]]; then
      tmux split-window -h "$*"

    else 
     
      tmux has-session -t ${screenname} 2>/dev/null
      if [[ $? != 0 ]]; then
        tmux new-session -d -s ${screenname}
        tmux send-keys -t ${screenname} "$*" C-m
        tmux attach-session -t ${screenname}
      else
        tmux attach-session -t ${screenname}
      fi
    fi

  else
    local distscreen="/usr/bin/screen"
    local brewscreen="/var/home/linuxbrew/.linuxbrew/bin/screen"

    if [[ -e "${distscreen}" ]]; then
      ${distscreen} $@
    elif [[ -e "${brewscreen}" ]]; then
      ${brewscreen} $@
    else
      echo "screen not found: please use override or tmux"
    fi
  fi
}
