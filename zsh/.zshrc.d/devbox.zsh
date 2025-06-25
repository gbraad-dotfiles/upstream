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

  local SUFFIX="box"
  local PREFIX=$1
  local COMMAND=$2
  local BOXNAME=${PREFIX}${SUFFIX}
  shift 2

  local START_SHELL=$(boxini --get devbox.shell)

  case "$COMMAND" in
    "create")
      distrobox create --yes --init -i $(generate_devbox_name $PREFIX) ${BOXNAME}
      echo "$0 $PREFIX enter"
      ;;
    "start")
      if (! podman ps -a --format "{{.Names}}" | grep -q ${BOXNAME}); then
        devbox ${PREFIX} create
      fi
      distrobox enter ${BOXNAME} -T -- :
      ;;
    "stop")
      distrobox stop ${BOXNAME}
      ;;
    "kill" | "rm" | "remove")
      distrobox rm ${BOXNAME}
      ;;
    "enter" | "shell")
      if (! podman ps -a --format "{{.Names}}" | grep -q ${BOXNAME}); then
        devbox ${PREFIX} create
        sleep 1
      fi
      if (podman ps --filter "name=${BOXNAME}" --filter "status=created" --filter "status=stopped" | grep -q ${BOXNAME}); then
        devbox ${PREFIX} start
        sleep 2
      fi
      distrobox enter ${BOXNAME}
      ;;
    "export")
      podman exec ${BOXNAME} su ${USER} -c "export XDG_DATA_DIRS=/usr/local/share:/usr/share; export XDG_DATA_HOME=${HOME}/.local/share; distrobox-export --app $@"
      ;;
    "sysctl" | "systemctl" | "systemd")
      if (podman ps --filter "name=${BOXNAME}" --filter "status=stopped" | grep -q ${BOXNAME}); then
        echo "${BOXNAME} not running"
        return
      fi
      if (! podman ps -a --format "{{.Names}}" | grep -q ${BOXNAME}); then
        echo "${BOXNAME} not created"
        return
      fi

      devbox ${PREFIX} exec systemctl $@
      ;;
    "ps")
      devbox ${PREFIX} exec ps -ax $@
      ;;
    "status")
      PAGER=""
      if [[ $- != *i* ]]; then
        PAGER="--no-pager"
      fi
      devbox ${PREFIX} sysctl status ${PAGER} $@
      ;;
    "screen")
      devbox ${PREFIX} dot screen
      ;;
    "apps")
      devbox ${PREFIX} dot apps $*
      ;;
    "dot")
      devbox ${PREFIX} exec sudo -i -u ${USER} zsh -c "dotfiles source; export DISPLAY=:0; $*" 
      ;;
    "dotfiles")
      devbox ${PREFIX} user dotfiles $*
      ;;
    "root" | "su")
      devbox ${PREFIX} exec ${START_SHELL}
      ;;
    "user")
      devbox ${PREFIX} exec sudo -i -u ${USER} $*
      ;;
    "exec")
      if (! podman ps -a --format "{{.Names}}" | grep -q ${BOXNAME}); then
        devbox ${PREFIX} create
        sleep 1
      fi
      if (podman ps --filter "name=${BOXNAME}" --filter "status=created" --filter "status=stopped" | grep -q ${BOXNAME}); then
        devbox ${PREFIX} start
        sleep 2
      fi
      podman exec -it ${BOXNAME} $@
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
  box() { devbox "$@" }
fi
