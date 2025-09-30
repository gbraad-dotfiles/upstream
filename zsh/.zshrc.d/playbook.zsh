#!/bin/zsh
playbook_remote() {
    if [ "$#" -lt 2 ]; then
        echo "Usage: $0 <ssh_target|podman container|macadam vmname> <ansible-playbook arguments...>"
        return 1
    fi

    local runner_and_target
    if [[ "$1" == "macadam" ]]; then
        runner_and_target=("macadam" "ssh" "$2")
        shift 2
    elif [[ "$1" == "podman" ]]; then
        # not tested yet
        runner_and_target=("podman" "exec" "-i" "$2")
        shift 2
    else
        runner_and_target=("ssh" "$1")
        shift
    fi

    local playbook_file=""
    local filtered_args=()
    for arg in "$@"; do
        if [[ "$arg" == *.yml || "$arg" == *.yaml ]]; then
            playbook_file="$arg"
        else
            filtered_args+=("$arg")
        fi
    done

    if [ -z "${playbook_file}" ] || [ ! -f "${playbook_file}" ]; then
        echo "Could not find playbook file in arguments or file does not exist."
        return 1
    fi

    ${runner_and_target} which ansible-playbook >/dev/null 2>&1 || {
        echo "ansible-playbook not found on remote host"
        return 1
    }

    local remote_file="/tmp/$(basename ${playbook_file})"

    cat ${playbook_file} | ${runner_and_target} sh -c "cat > '${remote_file}'" 
    ${runner_and_target} ansible-playbook ${remote_file} ${filtered_args[@]}
    ${runner_and_target} rm -f ${remote_file}

    return 0
}

playbook() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 [playbook] <command> [args...]"
    return 1
  fi
  
  local PLAYBOOK=$1
  local COMMAND=$2
  local HOST
  shift 2

  if [ ! -f "${PLAYBOOK}" ]; then
    echo "Playbook does not exist."
    return 1
  fi

  case "${COMMAND}" in
    "edit")
      ${EDITOR} ${PLAYBOOK}
      ;;
    "execute" | "run" | "local")
      ansible-playbook ${PLAYBOOK} $@
      ;;
    "host" | "hosts")
      HOST=$1
      shift
      ansible-playbook -i ${HOST}, ${PLAYBOOK} $@
      ;;
    "remote")
      HOST=$1
      shift
      playbook_remote ${HOST} ${PLAYBOOK} $@
      ;;
    "devenv")
      HOST=$1
      shift
      devenv ${HOST} playbook ${PLAYBOOK} $@
      ;;
    "devbox")
      HOST=$1
      shift
      devbox ${HOST} playbook ${PLAYBOOK} $@
      ;;
    "machine")
      HOST=$1
      shift
      machine ${HOST} playbook ${PLAYBOOK} $@
      ;;
    *)
      echo "Unknown command: $0 ${COMMAND}"
      ;;
  esac
}
