#!/bin/zsh

CONFIG="${HOME}/.config/dotfiles/devenv"
if [[ ! -f $CONFIG ]]; then
  echo "Configuration file missing: $CONFIG"
  return
fi
alias devini="git config -f $CONFIG"

devenv() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <prefix> <command> [args...]"
    return 1
  fi

  local SUFFIX="sys"
  local PREFIX=$1
  local COMMAND=$2
  local ENVNAME=${PREFIX}env
  local SYSNAME=${PREFIX}${SUFFIX}
  shift 2

  local START_SHELL=$(devini --get devenv.shell)
  local IMAGE_USER=$(devini --get devenv.user)
  local START_ARGS=(
    "--user=root"
    "--cap-add=NET_RAW"
    "--cap-add=NET_ADMIN"
    "--cap-add=SYS_ADMIN"
    "--userns=keep-id"
    "--pull=newer"
  )
  [[ -e /dev/net/tun ]] && START_ARGS+=("--device=/dev/net/tun")
  [[ -e /dev/fuse ]] && START_ARGS+=("--device=/dev/fuse")
  [[ -e /dev/dri ]] && START_ARGS+=("--device=/dev/dri")

  # issue as some containers do not have this yet
  #"--workdir=$(devini --get devenv.workdir)"
  local START_PATHS=(
    "-v" "${HOME}/Projects:/home/${IMAGE_USER}/Projects"
    "-v" "${HOME}/Documents:/home/${IMAGE_USER}/Documents"
    "-v" "${HOME}/Downloads:/home/${IMAGE_USER}/Downloads"
    "-v" "${HOME}/Projects:/var/home/${IMAGE_USER}/Projects"
    "-v" "${HOME}/Documents:/var/home/${IMAGE_USER}/Documents"
    "-v" "${HOME}/Downloads:/var/home/${IMAGE_USER}/Downloads"
    "-v" "/tmp/.X11-unix:/tmp/.X11-unix"
  )
  
  case "$COMMAND" in
    "env" | "run" | "rootenv")
      podman run --rm -it --hostname ${HOSTNAME}-${ENVNAME} --entrypoint='' \
        "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX) ${START_SHELL} $@
      ;;
    "userenv" | "userrun")
      devenv $PREFIX run -c "su - gbraad"
      ;;
    "create")
      podman create --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --systemd=always "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX)
      ;;
    "sys" | "system")
      #for (( i=0; i < ${#START_PATHS[@]}; i++ )); do
      #  START_PATHS[$i]="${START_PATHS[$i]/#\~/$HOME}"
      #done
      podman run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --systemd=always "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX)
      # TODO: systemd only when able to check for running state
      #&& (mkdir -p ${HOME}/.config/systemd/user && cd ${HOME}/.config/systemd/user \
      #&& podman generate systemd --name --files ${PREFIX}sys) \
      #&& systemctl --user daemon-reload \
      #&& systemctl --user start container-${PREFIX}sys
      ;;
    "noinit" | "dumb")
      # For environments that can not start systemd
      podman run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --entrypoint "" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX) $(devini --get devenv.noinit)
      ;;
    "nosys" | "init")
      # For environments that can not start systemd
      podman run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --init --entrypoint "" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX) $(devini --get devenv.noinit)
      ;;
    "start")
      if (! podman ps -a --format "{{.Names}}" | grep -q ${SYSNAME}); then
        source /etc/os-release
        if [[ "$ID" == "idx" ]]; then
          devenv ${PREFIX} init
        else
          devenv ${PREFIX} system
        fi
      else
        podman start ${SYSNAME}
      fi
      #systemctl --user start container-${PREFIX}sys
      ;;
    "stop")
      #systemctl --user stop container-${PREFIX}sys
      podman stop ${SYSNAME}
      ;;
    "kill" | "rm" | "remove")
      #systemctl --user stop container-${PREFIX}sys
      podman rm -f ${SYSNAME}
      ;;
    "exec" | "execute")
      if (! podman ps -a --format "{{.Names}}" | grep -q ${SYSNAME}); then
        devenv ${PREFIX} sys
        sleep 1
      fi
      if (podman ps --filter "name=${PREFIX}sys"  --filter "status=created" --filter "status=stopped" | grep -q ${PREFIX}sys); then
        devenv ${PREFIX} start
        sleep 2
      fi
      podman exec -it ${SYSNAME} $@
      ;;
    "root" | "su")
      devenv ${PREFIX} exec ${START_SHELL}
      ;;
    "user" | "sh" | "shell")
      devenv ${PREFIX} exec sudo -i -u ${IMAGE_USER} $*
      ;;
    "sysctl" | "systemctl" | "systemd")
      if (podman ps --filter "name=${PREFIX}sys" --filter "status=stopped" | grep -q ${PREFIX}sys); then
        echo "${SYSNAME} not running"
        return
      fi
      if (! podman ps -a --format "{{.Names}}" | grep -q ${PREFIX}sys); then
        echo "${SYSNAME} not created"
        return
      fi

      devenv ${PREFIX} exec systemctl $@
      ;;
    "ps")
      devenv ${PREFIX} exec ps -ax $@
      ;;
    "status")
      PAGER=""
      if [[ $- != *i* ]]; then
        PAGER="--no-pager"
      fi
      devenv ${PREFIX} sysctl status ${PAGER} $@
      ;;
    "tmux")
      command="-c tmux -2 $@"
      devenv ${PREFIX} user $command
      ;;
    "apps")
      devenv ${PREFIX} dot apps $*
      ;;
    "dot")
      devenv ${PREFIX} exec sudo -i -u ${IMAGE_USER} zsh -c "dotfiles source; export DISPLAY=:0; $*"
      ;;
    "dotfiles")
      devenv ${PREFIX} user dotfiles $@
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}


generate_image_name() {
  local PREFIX=$1
  local IMAGE=$(devini --get "images.${PREFIX}")

  if [ -z "${IMAGE}" ]; then
    echo "Unknown distro: $PREFIX"
    exit 1
  fi

  echo ${IMAGE}
}

# legacy aliases

generate_aliases() {
  local PREFIX=$1
  alias ${PREFIX}env="devenv ${PREFIX} env"
  alias ${PREFIX}sys="devenv ${PREFIX} sys"
  alias ${PREFIX}root="devenv ${PREFIX} root"
  alias ${PREFIX}user="devenv ${PREFIX} user"
  alias ${PREFIX}tmux="devenv ${PREFIX} tmux"
  alias ${PREFIX}build="devenv ${PREFIX} tmux attach-session -t build || dev ${PREFIX} tmux new-session -s build"
}

if [[ $(devini --get "devenv.aliases") == true ]]; then
  alias dev="devenv"

  generate_aliases "fed"
  generate_aliases "deb"
  generate_aliases "alp"
  generate_aliases "cen"
  generate_aliases "go"
  generate_aliases "ubi"
  generate_aliases "ubu"
  generate_aliases "alm"
  generate_aliases "sus"
  generate_aliases "tum"

  # Base on host distro
  if [ ! -e /etc/os-release ]; then
	return
  fi

  source /etc/os-release
  case "$ID" in
    "fedora" | "bazzite")
        alias devsys="fedsys"
        alias devroot="fedroot"
        alias devuser="feduser"
        alias devtmux="fedtmux"
        ;;
    "debian" | "ubuntu")
        alias devsys="debsys"
        alias devroot="debroot"
        alias devuser="debuser"
        alias devtmux="debtmux"
        ;;
  esac
fi
