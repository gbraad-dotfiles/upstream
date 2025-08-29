#!/bin/zsh

devenv_commands=(
  status start stop remove from shell
)

devenv_prefixes() {
  local key="images"
  local output prefixes
  output=($(dotini devenv --list | grep "^${key}\." || true))
  prefixes=(${output//${key}./})
  prefixes=(${prefixes//=*/})
  printf "%s\n" "${prefixes[@]}"
}

devenv() {
  local SUFFIX="sys"
  if [ $# -lt 2 ]; then
    podman ps -a --filter "name=${SUFFIX}$" --format "{{.Names}} - {{.Status}}"
    return 1
  fi

  local PREFIX=$1
  local COMMAND=$2
  local ENVNAME=${PREFIX}env
  local SYSNAME=${PREFIX}${SUFFIX}
  shift 2

  local START_SHELL=$(dotini devenv --get devenv.shell)
  local IMAGE_USER=$(dotini devenv --get devenv.user)

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
  #"--workdir=$(dotini devenv --get devenv.workdir)"

  local SELINUX_ENABLED=0
  if command -v getenforce &>/dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
    SELINUX_ENABLED=1
  fi

  local MOUNT_OPTIONS=""
  if [[ "$SELINUX_ENABLED" -eq 1 ]]; then
    MOUNT_OPTIONS=":z"
  fi

  local START_PATHS=(
    "-v" "${HOME}/Projects:/home/${IMAGE_USER}/Projects${MOUNT_OPTIONS}"
    "-v" "${HOME}/Documents:/home/${IMAGE_USER}/Documents${MOUNT_OPTIONS}"
    "-v" "${HOME}/Downloads:/home/${IMAGE_USER}/Downloads${MOUNT_OPTIONS}"
    "-v" "${HOME}/Projects:/var/home/${IMAGE_USER}/Projects${MOUNT_OPTIONS}"
    "-v" "${HOME}/Documents:/var/home/${IMAGE_USER}/Documents${MOUNT_OPTIONS}"
    "-v" "${HOME}/Downloads:/var/home/${IMAGE_USER}/Downloads${MOUNT_OPTIONS}"
    "-v" "/tmp/.X11-unix:/tmp/.X11-unix"
  )
  
  case "$COMMAND" in
    "exists")
      return $(podman ps -a --format "{{.Names}}" | grep -q ${SYSNAME})
      ;;
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
      ;;
    "noinit" | "dumb")
      # For environments that can not start systemd
      podman run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --entrypoint "" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX) $(dotini devenv --get devenv.noinit)
      ;;
    "nosys" | "init")
      # For environments that can not start systemd
      podman run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --init --entrypoint "" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $PREFIX) $(dotini devenv --get devenv.noinit)
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
      if (podman ps --filter "name=${SYSNAME}" --filter "status=created" --filter "status=stopped" | grep -q ${SYSNAME}); then
        devenv ${PREFIX} start
        sleep 2
      fi
      podman exec -it ${SYSNAME} $@
      ;;
    "root" | "su")
      devenv ${PREFIX} exec ${START_SHELL}
      ;;
    "sudo")
      devenv ${PREFIX} exec sudo $@
      ;;
    "user" | "sh" | "shell")
      devenv ${PREFIX} exec sudo -i -u ${IMAGE_USER} $*
      ;;
    "usercmd")
      devenv ${PREFIX} exec su ${IMAGE_USER} -l -c $*
      ;;
    "sysctl" | "systemctl" | "systemd")
      if (podman ps --filter "name=${SYSNAME}" --filter "status=stopped" | grep -q ${SYSNAME}); then
        echo "${SYSNAME} not running"
        return
      fi
      if (! podman ps -a --format "{{.Names}}" | grep -q ${SYSNAME}); then
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
    "screen")
      devenv ${PREFIX} dot screen
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
    "playbook")
      remote_playbook podman ${SYSNAME} $@ # <filename> <...> 
      ;;
    "from")
      # use $1 as prefix value for the image
      podman run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --systemd=always "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_image_name $1)
      ;;
    "tsconnect")
      local HOSTNAME=$(hostname)
      local LAST3=${HOSTNAME: -3}
      secrets var tailscale_authkey
      devenv ${PREFIX} sudo tailscale up --auth-key "${TAILSCALE_AUTHKEY}" --hostname ${SYSNAME}-${LAST3} --operator ${IMAGE_USER} --ssh
      ;;
    "export")
      local from=$1
      local image=""
      if [[ -n "$from" ]]; then
        image=$(generate_image_name $from)
      else
        image=$(generate_image_name $PREFIX)
      fi
      devenv-export-service $PREFIX $image
      echo "Start with:\nsystemctl --user start dotfiles-devenv-${PREFIX}"
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}

generate_image_name() {
  local PREFIX=$1
  local IMAGE=$(dotini devenv --get "images.${PREFIX}")

  if [ -z "${IMAGE}" ]; then
    echo "Unknown distro: $PREFIX"
    exit 1
  fi

  echo ${IMAGE}
}

if [[ $(dotini devenv --get "devenv.aliases") == true ]]; then
  alias ds="apps devenvs"
  dev() { devenv "$@" }
fi

devenv-export-service() {
  local name="$1"
  local image="$2"
  local sysname=${name}sys

  if [[ -z "$image" ]]; then
    echo "Usage: devenv-export-service <name> <image>"
    return 1
  fi

  local service_dir="${HOME}/.config/containers/systemd"
  local service_name="dotfiles-devenv-${name}.container"
  local service_file="${service_dir}/${service_name}"

  mkdir -p "$service_dir"
  cat > "$service_file" <<EOF
[Unit]
Description=${name}

[Container]
Image=${image}
ContainerName=${sysname}

[Install]
WantedBy=default.target
EOF

  if ! notify-send "Exported" "${service_name}" > /dev/null 2>&1; then
    echo "Exported" ${service_name}
  fi
  systemctl --user daemon-reload
}
