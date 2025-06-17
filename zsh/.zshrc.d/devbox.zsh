#!/bin/zsh

CONFIG="${HOME}/.config/dotfiles/devbox"
if [[ ! -f $CONFIG ]]; then
  echo "Configuration file missing: $CONFIG"
  return
fi
alias boxini="git config -f $CONFIG"

devbox() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <prefix> <command> [args...]"
    return 1
  fi

  local PREFIX=$1
  local COMMAND=$2
  shift 2

  case "$COMMAND" in
    "create")
      distrobox create --yes --init -i $(generate_devbox_name $PREFIX) ${PREFIX}box
      echo "$0 $PREFIX enter"
      ;;
    "stop")
      ;;
    "kill" | "rm" | "remove")
      distrobox rm ${PREFIX}box
      ;;
    "enter" | "shell")
      distrobox enter ${PREFIX}box
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}


generate_devbox_name() {
  local PREFIX=$1
  local IMAGE=$(boxini --get "images.${PREFIX}")

  if [ -z "${IMAGE}" ]; then
    echo "Unknown distro: $PREFIX"
    exit 1
  fi

  echo ${IMAGE}
}

if [[ $(boxini --get "devbox.aliases") == true ]]; then
  alias box="devbox"
fi
