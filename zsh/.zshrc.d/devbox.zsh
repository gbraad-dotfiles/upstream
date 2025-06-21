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
      distrobox stop ${PREFIX}box
      ;;
    "kill" | "rm" | "remove")
      distrobox rm ${PREFIX}box
      ;;
    "enter" | "shell")
      distrobox enter ${PREFIX}box
      ;;
    "export")
      podman exec ${PREFIX}box su ${USER} -c "export XDG_DATA_DIRS=/usr/local/share:/usr/share; export XDG_DATA_HOME=${HOME}/.local/share; distrobox-export --app $@"
      ;;
    "apps")
      devbox ${PREFIX} dot apps $*
      ;;
    "dot")
      devbox ${PREFIX} dotfiles source; $@ 
      ;;
    "dotfiles")
      devbox ${PREFIX} exec dotfiles $@
      ;;
    "user")
      devbox ${PREFIX} exec sudo -i -u ${USER} $@
      ;;
    "exec")
      podman exec -it ${prefix}box $@
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
