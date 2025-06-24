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
