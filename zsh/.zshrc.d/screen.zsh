#!/bin/zsh

screen () {
  local tmux="tmux"
  # Already handled in tmux.zsh
  #if [ ! -L "${HOME}/.tmux.conf" ] || [ "$(readlink "${HOME}/.tmux.conf")" != "${HOME}/.dotfiles/tmux/.tmux.conf" ]; then
  #  tmux=("tmux" "-f" "${HOME}/.dotfiles/tmux/.tmuxdot.conf")
  #fi

  local OVERRIDE=$(dotini screen --bool "screen.override")
  if [[ ${OVERRIDE} == true ]]; then
    local screenname="screen"

    if [[ -n "${TMUX}" ]]; then
      
      $tmux new-window $*
    else
      $tmux has-session -t ${screenname} 2>/dev/null
      if [[ $? != 0 ]]; then

        $tmux new-session -d -s ${screenname}
        $tmux send-keys -t ${screenname} "$*" C-m
        $tmux attach-session -t ${screenname}
      else
        $tmux attach-session -t ${screenname}
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
