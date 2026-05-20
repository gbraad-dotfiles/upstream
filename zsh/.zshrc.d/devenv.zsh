#!/bin/zsh

devenv_commands=(
  status create start stop remove from apps playbook tsconnect service-install shell
)

devenv_prefixes() {
  local key="images"
  local output prefixes
  output=($(dotini devenv --list | grep "^${key}\." || true))
  prefixes=(${output//${key}./})
  prefixes=(${prefixes//=*/})
  printf "%s\n" "${prefixes[@]}"
}

devenv_targets() {
  devenv | awk -F' - ' '{sub(/sys$/, "", $1); print $1 "\t" $2}'
}

devenv_running_targets() {
  devenv | awk -F' - ' '$2 ~ /^Up/ {sub(/sys$/, "", $1); print $1 "\t" $2}'
}

_devenv_runtime() {
  local rt=$(dotini devenv --get devenv.runtime 2>/dev/null)

  # Force "containerd" to "nerdctl"
  if [[ "$rt" == "containerd" ]]; then
    echo "nerdctl"
  fi

  echo "${rt:-podman}"
}

_devenv_cgroupmgr() {
  local rt=$(dotini devenv --get devenv.cgroupmgr 2>/dev/null)
  echo "${rt:-default}"
}

devenv() {
  local SUFFIX="sys"
  local RUNTIME=$(_devenv_runtime)

  if [ $# -lt 2 ]; then
    ${RUNTIME} ps -a --filter "name=${SUFFIX}$" --format "{{.Names}} - {{.Status}}"
    return 1
  fi

  local PREFIX=$1
  local COMMAND=$2
  local ENVNAME=${PREFIX}env

  local SYSNAME=${PREFIX}${SUFFIX}
  [[ $PREFIX == "podmansh" ]] && SYSNAME="podmansh"
  shift 2

  local START_SHELL=$(dotini devenv --get devenv.shell)
  local IMAGE_USER=$(dotini devenv --get devenv.user)

  local PULL_ARG="--pull=newer"
  [[ "${RUNTIME}" == "nerdctl" ]] && PULL_ARG="--pull=always"

  local START_ARGS=(
    "--tmpfs" "/run"
    "--tmpfs" "/tmp"
    "--user=root"
    "--cap-add=NET_RAW"
    "--cap-add=NET_ADMIN"
    "--cap-add=SYS_ADMIN"
    "${PULL_ARG}"
  )
  # --userns=keep-id is podman-specific
  [[ "${RUNTIME}" == "podman" ]] && START_ARGS+=("--userns=keep-id")

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
    "-v" "/sys/fs/cgroup:/sys/fs/cgroup:rw"
    "-v" "${HOME}/Projects:/home/${IMAGE_USER}/Projects${MOUNT_OPTIONS}"
    "-v" "${HOME}/Documents:/home/${IMAGE_USER}/Documents${MOUNT_OPTIONS}"
    "-v" "${HOME}/Downloads:/home/${IMAGE_USER}/Downloads${MOUNT_OPTIONS}"
    "-v" "${HOME}/Projects:/var/home/${IMAGE_USER}/Projects${MOUNT_OPTIONS}"
    "-v" "${HOME}/Documents:/var/home/${IMAGE_USER}/Documents${MOUNT_OPTIONS}"
    "-v" "${HOME}/Downloads:/var/home/${IMAGE_USER}/Downloads${MOUNT_OPTIONS}"
    "-v" "/tmp/.X11-unix:/tmp/.X11-unix"
  )
  
  local CGROUPMGR=$(_devenv_cgroupmgr)
  local SYSTEMD_ARG=()
  if [[ "${RUNTIME}" == "podman" ]]; then
    # If cgroup is 'default', let Podman decide (usually systemd)
    if [[ "$CGROUPMGR" != "default" ]]; then
      SYSTEMD_ARG+=("--cgroup-manager=${CGROUPMGR}")
    fi
    SYSTEMD_ARG+=("--systemd=always")
  elif [[ "${RUNTIME}" == "nerdctl" ]]; then
    # If cgroup is 'default' for nerdctl, we force 'none' to avoid the D-Bus crash
    local mgr="${CGROUPMGR}"
    [[ "$mgr" == "default" ]] && mgr="none"
    
    SYSTEMD_ARG=(
      "--privileged" 
      "--cgroupns=host" 
      "--cgroup-manager=${mgr}"
    )
  fi

  case "$COMMAND" in
    "exists")
      return $(${RUNTIME} ps -a --format "{{.Names}}" | grep -q ${SYSNAME})
      ;;
    "status")
      devenv_targets | awk -v prefix="$PREFIX" '$1 == prefix {print $2}'
      ;;
    "env" | "run" | "ephemeral")
      ${RUNTIME} run --rm -it --hostname ${HOSTNAME}-${ENVNAME} --entrypoint='' \
        "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_devenv_name $PREFIX) ${START_SHELL} $@
      ;;
    #"userenv" | "userrun")
    #  devenv $PREFIX run -c "su - gbraad"
    #  ;;
    "create")
      ${RUNTIME} create --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        "${SYSTEMD_ARG[@]}" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_devenv_name $PREFIX)
      ;;
    "sys" | "system")
      ${RUNTIME} run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        "${SYSTEMD_ARG[@]}" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_devenv_name $PREFIX)
      ;;
    "noinit" | "dumb")
      # For environments that can not start systemd
      ${RUNTIME} run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --entrypoint "" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_devenv_name $PREFIX) $(dotini devenv --get devenv.noinit)
      ;;
    "nosys" | "init")
      # For environments that can not start systemd
      ${RUNTIME} run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} \
        --init --entrypoint "" "${START_ARGS[@]}" "${START_PATHS[@]}" \
        $(generate_devenv_name $PREFIX) $(dotini devenv --get devenv.noinit)
      ;;
    "start")
      if (! ${RUNTIME} ps -a --format "{{.Names}}" | grep -q ${SYSNAME}); then
        source /etc/os-release
        if [[ "$ID" == "idx" ]]; then
          devenv ${PREFIX} init
        else
          devenv ${PREFIX} system
        fi
      else
        ${RUNTIME} start ${SYSNAME}
      fi
      ;;
    "stop")
      ${RUNTIME} stop ${SYSNAME}
      ;;
    "kill" | "rm" | "remove")
      ${RUNTIME} rm -f ${SYSNAME}
      ;;
    "exec" | "execute")
      if (! ${RUNTIME} ps -a --format "{{.Names}}" | grep -q ${SYSNAME}); then
        devenv ${PREFIX} sys
        sleep 1
      fi
      if (${RUNTIME} ps --filter "name=${SYSNAME}" --filter "status=created" --filter "status=stopped" | grep -q ${SYSNAME}); then
        devenv ${PREFIX} start
        sleep 2
      fi
      local _it_flag="-it"; [[ -t 0 ]] || _it_flag="-i"
      ${RUNTIME} exec ${_it_flag} -e TERM="${TERM}" ${SYSNAME} $@
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
    "systemctl" | "systemd")
      if (${RUNTIME} ps --filter "name=${SYSNAME}" --filter "status=stopped" | grep -q ${SYSNAME}); then
        echo "${SYSNAME} not running"
        return
      fi
      if (! ${RUNTIME} ps -a --format "{{.Names}}" | grep -q ${SYSNAME}); then
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
      playbook_remote ${RUNTIME} ${SYSNAME} $@ # <filename> <...>
      ;;
    "from")
      # use $1 as prefix value for the image
      ${RUNTIME} run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} "${SYSTEMD_ARG[@]}" "${START_ARGS[@]}" "${START_PATHS[@]}" $(generate_devenv_name $1)
      ;;
    "from-devbox")
      ${RUNTIME} run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} "${SYSTEMD_ARG[@]}" "${START_ARGS[@]}" "${START_PATHS[@]}" $(generate_devbox_name $1)
      ;;
    "from-image")
      # use $1 as prefix value for the image
      ${RUNTIME} run -d --name=${SYSNAME} --hostname ${HOSTNAME}-${SYSNAME} "${SYSTEMD_ARG[@]}" "${START_ARGS[@]}" "${START_PATHS[@]}" $1
      ;;
    "tsconnect")
      local HOSTNAME=$(hostname)
      local LAST3=${HOSTNAME: -3}
      secrets var tailscale_authkey
      devenv ${PREFIX} sudo tailscale up --auth-key "${TAILSCALE_AUTHKEY}" --hostname ${SYSNAME}-${LAST3} --operator ${IMAGE_USER} --ssh
      ;;
    "service-install")
      local from=$1
      local image=""
      if [[ -n "$from" ]]; then
        image=$(generate_image_name $from)
      else
        image=$(generate_image_name $PREFIX)
      fi
      devenv-service-install $PREFIX $image
      echo "Start with:\nsystemctl --user start dotfiles-devenv-${PREFIX}"
      ;;
    *)
      ;;
  esac
}

generate_devenv_name() {
  local PREFIX=$1
  local IMAGE=$(dotini devenv --get "images.${PREFIX}")

  if [ -z "${IMAGE}" ]; then
    echo "Unknown distro: $PREFIX"
    return 1
  fi

  echo ${IMAGE}
}

if [[ $(dotini devenv --get "devenv.aliases") == true ]]; then
  alias ds="app devenvs"
  dev() { devenv "$@" }
fi

devenv-quadlet-install() {
  local name="$1"
  local image="$2"
  local sysname=${name}sys

  if [[ -z "$image" ]]; then
    echo "Usage: devenv-export-service <name> <image>"
    return 1
  fi

  local service_dir="${HOME}/.config/containers/systemd"
  local service_name="dotfiles-quadlet-${name}.container"
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

