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
