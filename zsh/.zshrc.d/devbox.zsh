#!/bin/zsh

devbox_commands=(
  status create start stop remove from apps playbook tsconnect export shell
)

devbox_prefixes() {
  local key="images"
  local output prefixes
  output=($(dotini devbox --list | grep "^${key}\." || true))
  prefixes=(${output//${key}./})
  prefixes=(${prefixes//=*/})
  printf "%s\n" "${prefixes[@]}"
}

devbox() {
  if ! apps distrobox check; then
    apps distrobox install
  fi

  local SUFFIX="box"
  if [ $# -lt 2 ]; then
    podman ps -a --filter "name=${SUFFIX}$" --format "{{.Names}} - {{.Status}}"
    return 1
  fi

  local PREFIX=$1
  local COMMAND=$2
  local BOXNAME=${PREFIX}${SUFFIX}
  shift 2

  local START_SHELL=$(dotini devbox --get devbox.shell)
  local IMAGE_USER=$(dotini devbox --get devbox.user)

  case "$COMMAND" in
     "exists")
      return $(podman ps -a --format "{{.Names}}" | grep -q ${BOXNAME})
      ;;
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
    "enter")
      #if [[ "${USER}" != "${IMAGE_USER}" ]]; then
      #   echo "User is different from image. Please use '$0 ${PREFIX} shell' instead."
      #   return 1
      #fi
      if (! podman ps -a --format "{{.Names}}" | grep -q ${BOXNAME}); then
        devbox ${PREFIX} create
        sleep 1
      fi
      if (podman ps --filter "name=${BOXNAME}" --filter "status=created" --filter "status=stopped" | grep -q ${BOXNAME}); then
        devbox ${PREFIX} start
        sleep 2
      fi
      distrobox enter ${BOXNAME} -- ${START_SHELL}
      ;;
    "export")
      podman exec ${BOXNAME} su ${IMAGE_USER} -c "export XDG_DATA_DIRS=/usr/local/share:/usr/share; export XDG_DATA_HOME=${HOME}/.local/share; distrobox-export --app $@"
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
      devbox ${PREFIX} exec sudo -i -u ${IMAGE_USER} zsh -c "dotfiles source; export DISPLAY=:0; $*" 
      ;;
    "dotfiles")
      devbox ${PREFIX} user dotfiles $*
      ;;
    "root" | "su")
      devbox ${PREFIX} exec ${START_SHELL}
      ;;
    "sudo")
      devbox ${PREFIX} exec sudo $@
      ;;
    "user" | "sh" | "shell")
      # enter has no --user option
      devbox ${PREFIX} exec sudo -i -u ${IMAGE_USER} $*
      ;;
    "usercmd")
      devbox ${PREFIX} exec su ${IMAGE_USER} -l -c $*
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
    "playbook")
      remote_playbook podman ${BOXNAME} $@ # <filename> <...> 
      ;;
    "from")
      # use $1 as prefix value for the image
      distrobox create --yes --init -i $(generate_devbox_name $1) ${BOXNAME}
      echo "$0 $PREFIX enter"
      ;;
    "from-devenv")
      distrobox create --yes --init -i $(generate_devenv_name $PREFIX) ${BOXNAME}
      echo "$0 $PREFIX enter"
      ;;
    "tsconnect")
      local HOSTNAME=$(hostname)
      local LAST3=${HOSTNAME: -3}
      secrets var tailscale_authkey
      devenv ${PREFIX} sudo tailscale up --auth-key "${TAILSCALE_AUTHKEY}" --hostname ${SYSNAME}-${LAST3} --operator ${IMAGE_USER} --ssh
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}

generate_devbox_name() {
  local PREFIX=$1
  local IMAGE=$(dotini devbox --get "images.${PREFIX}")

  if [ -z "${IMAGE}" ]; then
    echo "Unknown distro: $PREFIX"
    exit 1
  fi

  echo ${IMAGE}
}

if [[ $(dotini devbox --get "devbox.aliases") == true ]]; then
  box() { devbox "$@" }
fi
