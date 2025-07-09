#!/bin/zsh

dotssh() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <user@host> <command>"
    return 1
  fi 

  local ADDRESS=$1
  shift 1
  local COMMAND='
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TERM=xterm-256color

if command -v dotfiles >/dev/null 2>&1 && typeset -f dotfiles >/dev/null 2>&1; then
 dotfiles source; __ARGS__
else
 if [ ! -d "${HOME}/.dotfiles" ]; then
 git clone https://github.com/gbraad-dotfiles/upstream.git ~/.dotfiles --depth 2
fi
 "${HOME}/.dotfiles/activate.sh" __ARGS__
fi
'
  local COMMAND_TO_SEND="${COMMAND//__ARGS__/$@}"
  ssh -X -t -o StrictHostKeyChecking=no ${ADDRESS} ${COMMAND_TO_SEND}
}

dotscreen() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <user@host>"
    return 1
  fi 

  dotssh $1 screen
}

