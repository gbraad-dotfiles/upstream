#!/bin/zsh
podman_playbook() {
    if [ "$#" -lt 2 ]; then
      echo "Usage: $0 <container_name> <ansible-playbook arguments...>"
      return 1
    fi

    local container="$1"
    shift
    
    if ! podman exec ${container} which ansible-playbook >/dev/null 2>&1; then
      echo "ansible-playbook not found in the container"
      return 1
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

    podman cp "${playbook_file}" "${container}:/tmp/"
    podman exec -it "${container}" ansible-playbook "/tmp/$(basename "${playbook_file}")" "${filtered_args[@]}"
    podman exec "${container}" rm "/tmp/$(basename "${playbook_file}")"

    return 0
}
