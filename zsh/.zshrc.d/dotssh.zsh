#!/bin/zsh

dotssh() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <address> <command>"
    return 1
  fi 

  local ADDRESS=$1
  shift 1

  ssh -X -t ${ADDRESS} "dotfiles source; $@"
}
