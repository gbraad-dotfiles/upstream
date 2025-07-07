#!/bin/zsh

dotssh() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <address> <command>"
    return 1
  fi 

  local ADDRESS=$1
  shift 1

  ssh -X -t ${ADDRESS} "export LANG=en_US.UTF-8; export LC_ALL=en_US.UTF-8; export TERM=xterm-256color; dotfiles source; $@"
}

#dotscreen() {
#  if [ $# -lt 1 ]; then
#    echo "Usage: $0 <address>"
#    return 1
#  fi 
#
#  dotssh $1 screen
#}

dotscreen() {
  local userhost="$1"
  if [[ -z "$userhost" ]]; then
    echo "Usage: dotscreen user@host"
    return 1
  fi

  ssh -X -t "$userhost" '
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    export TERM=xterm-256color

    if command -v dotfiles >/dev/null 2>&1 && typeset -f dotfiles >/dev/null 2>&1; then
      dotfiles source; screen
    else
      if [ ! -d "$HOME/.dotfiles" ]; then
        git clone https://github.com/gbraad-dotfiles/upstream.git ~/.dotfiles --depth 2
      fi
      "$HOME/.dotfiles/activate.sh" screen
    fi
  '
}
  
