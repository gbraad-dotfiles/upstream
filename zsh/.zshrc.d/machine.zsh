#!/bin/zsh

machine() { 
 if [ $# -lt 2 ]; then
    echo "Usage: $0 <prefix> <command> [args...]"
    return 1
  fi

  local PREFIX=$1
  local SYSNAME="machine-${PREFIX}"
  local COMMAND=$2
  shift 2

  local DISKFOLDER=$(dotini machine --get machine.diskfolder)
  DISKFOLDER="${DISKFOLDER/#\~/$HOME}"
  local IDENTITYPATH=$(dotini machine --get machine.identitypath)
  IDENTITYPATH="${IDENTITYPATH/#\~/$HOME}"
  local START_SHELL=$(dotini devenv --get devenv.shell)
  local IMAGE_USER=$(dotini machine --get machine.user)

  # ensuere folder exists
  if [ ! -d "${DISKFOLDER}" ]; then
    mkdir -p "${DISKFOLDER}"
  fi

  local START_ARGS=(
    "--cpus=$(dotini machine --get machine.vcpus)"
    "--memory=$(dotini machine --get machine.memory)"
    "--username=${IMAGE_USER}"
    "--ssh-identity-path=${IDENTITYPATH}"
  )

  case "$COMMAND" in
    "exists")
      return $(macadam list | grep -q -E "${SYSNAME} ")
      ;;
    "download")
      download "$(dotini machine --get disks.${PREFIX})" "${DISKFOLDER}/${PREFIX}.qcow2"
      ;;
    "system" | "create" | "init")
      macadam init --name "${SYSNAME}" "${START_ARGS[@]}" "${DISKFOLDER}/${PREFIX}.qcow2"
      ;;
    "restart" | "reboot")
      machine ${PREFIX} stop
      machine ${PREFIX} start
      ;;
    "start")
      macadam start "${SYSNAME}"
      ;;
    "stop")
      macadam stop "${SYSNAME}"
      ;;
    "kill" | "rm" | "remove")
      macadam rm "${SYSNAME}"
      ;;
    "console" | "shell" | "ssh")
      macadam ssh "${SYSNAME}"
      ;;
    "root" | "su")
      machine ${PREFIX} sudo ${START_SHELL} 
      ;;
    "sudo")
      machine ${PREFIX} exec sudo $@
      ;;
    "exec" | "user")
      macadam ssh "${SYSNAME}" "$@"
      ;;
    "switch")
      local CMD="sudo bootc switch $(dotini machine --get images.$1)"
      if [ "$PREFIX" = "local" ]; then
        eval $CMD
      else
        machine ${PREFIX} exec $CMD
      fi      
      ;;
    "copy-config" | "cc")
      local IMAGE=""
      IMAGE="$(dotini machine --get disks.${PREFIX})"
      $(dotini machine --add disks.$1 "${IMAGE}")
      ;;
    "playbook")
      echo "not yet implemented"
      ;;
    "from")
      # use $1 as prefix value for the image
      macadam init --name "${SYSNAME}" "${START_ARGS[@]}" "${DISKFOLDER}/$1.qcow2"
      ;;
    "tsconnect")
      local HOSTNAME=$(hostname)
      local LAST3=${HOSTNAME: -3}
      secrets var tailscale_authkey
      machine ${PREFIX} sudo tailscale up --auth-key "${TAILSCALE_AUTHKEY}" --hostname ${SYSNAME}-${LAST3} --operator ${IMAGE_USER} --ssh
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}

download_from_registry() {
    image_reference=$1
    output_file=$2
    
    echo "Downloading container image: $image_reference"
    
    # Parse the image reference
    if [[ $image_reference == *:* ]]; then
        registry_and_repo=${image_reference%:*}
        tag=${image_reference#*:}
    else
        registry_and_repo=$image_reference
        tag="latest"
    fi
    
    # Parse registry and repository
    if [[ $registry_and_repo == */* ]]; then
        registry=${registry_and_repo%%/*}
        repository=${registry_and_repo#*/}
    else
        # Default to DockerHub if no registry specified
        registry="registry-1.docker.io"
        repository=$registry_and_repo
    fi
    
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Get a token for authentication (for GitHub Container Registry)
    if [[ $registry == "ghcr.io" ]]; then
        echo "Authenticating with GitHub Container Registry..."
        token_response=$(curl -s "https://ghcr.io/token?scope=repository:$repository:pull&service=ghcr.io")
        token=$(echo $token_response | grep -o '"token":"[^"]*' | cut -d'"' -f4)
        auth_header="Authorization: Bearer $token"
    else
        # For other registries, might need different authentication methods
        # This is a simplified example for public images
        auth_header=""
    fi
    
    # Get the manifest to find the layers
    echo "Fetching manifest for $repository:$tag..."
    
    # First try the v2 manifest
    manifest=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
                  -H "$auth_header" \
                  "https://$registry/v2/$repository/manifests/$tag")
    
    # If we didn't get a v2 manifest, try v1
    if [[ $(echo $manifest | grep -c "schemaVersion") -eq 0 ]]; then
        manifest=$(curl -s -H "Accept: application/vnd.docker.distribution.manifest.v1+json" \
                      -H "$auth_header" \
                      "https://$registry/v2/$repository/manifests/$tag")
    fi
    
    # Create a directory to extract the layers
    mkdir -p "$temp_dir/rootfs"
    
    # For v2 manifests, get the layer digests
    if [[ $(echo $manifest | grep -c "schemaVersion.:2") -gt 0 ]]; then
        echo "Processing v2 manifest..."
        # Extract layer digests
        layer_digests=($(echo $manifest | grep -o '"digest":"sha256:[^"]*' | cut -d':' -f3))
        
        # Download and extract each layer
        for digest in ${layer_digests[@]}; do
            echo "Downloading layer: $digest"
            curl -s -L -H "$auth_header" \
                 "https://$registry/v2/$repository/blobs/sha256:$digest" \
                 -o "$temp_dir/layer.tar.gz"
            
            # Extract the layer to our rootfs directory
            tar -xzf "$temp_dir/layer.tar.gz" -C "$temp_dir/rootfs" 2>/dev/null || true
        done
    else
        # For v1 manifests or if v2 extraction fails
        echo "Falling back to podman pull if available..."
        if command -v podman &> /dev/null; then
            podman pull "$image_reference"
            container_id=$(podman create "$image_reference" sh)
            podman export "$container_id" | tar -xf - -C "$temp_dir/rootfs"
            podman rm "$container_id" >/dev/null
        else
            echo "Error: Could not process image manifest and podman is not available."
            return 1
        fi
    fi
    
    # Look for the disk.qcow2 file (or any variant)
    echo "Looking for disk image files in the container..."
    disk_files=($(find "$temp_dir/rootfs" -name "*.qcow2" -type f))
    
    if [[ ${#disk_files[@]} -eq 0 ]]; then
        echo "Error: No disk.qcow2 file found in the container image."
        return 1
    fi
    
    # If multiple disk files found, use the first one or look for specific names
    disk_file=${disk_files[0]}
    for file in ${disk_files[@]}; do
        if [[ $(basename "$file") == "disk.qcow2" ]]; then
            disk_file=$file
            break
        fi
    done
    
    echo "Found disk image: $disk_file"
    
    # Copy to the final output location
    cp "$disk_file" "$output_file"
    echo "Disk image extracted to $output_file"
    
    # Clean up
    rm -rf "$temp_dir"
    
    return 0
}

download() {
    input=$1
    final_output_file=$2

    # Check if this is a registry URL
    if [[ $input == registry:* ]]; then
        download_from_registry "${input#registry:}" "$final_output_file"
        return $?
    fi

    # Check if the input contains a range pattern
    if [[ $input == *\[*\]* ]]; then
        base_url="${input%\[*}"
        range="${input##*\[}"
        range="${range%\]*}"
        start_part="${range%-*}"
        end_part="${range#*-}"
        
        if [[ -z "$start_part" || -z "$end_part" ]]; then
            echo "Invalid range start or end"
            return 1
        fi
        
        # Remove any existing final output file to avoid appending to old data
        rm -f "$final_output_file"

        for i in $(seq $start_part $end_part); do
            part_url="${base_url}${i}"
            echo "Downloading $part_url and appending to $final_output_file..."
            curl -s -L "$part_url" -o - >> "$final_output_file"
            if [[ $? -ne 0 ]]; then
                echo "Error downloading $part_url. Exiting."
                return 1
            fi
        done
        echo "Download completed and concatenated into $final_output_file."
    else
        # Direct download
        url=$input
        echo "Downloading $url to $final_output_file..."
        curl -s -L $url -o $final_output_file
        if [[ $? -ne 0 ]]; then
            echo "Error downloading $url. Exiting."
            return 1
        fi
        echo "Download completed: $final_output_file."
    fi
}

if [[ $(dotini machine --get "machine.aliases") == true ]]; then
  alias mcn="machine"
fi

machine-export-service() {
  local vmname="$1"
  if [[ -z "$vmname" ]]; then
    echo "Usage: machine-export-service <vmname>"
    return 1
  fi

  local service_dir="${HOME}/.config/systemd/user"
  local service_name="dotfiles-machine-${vmname}.service"
  local service_file="${service_dir}/${service_name}"

  mkdir -p "$service_dir"
  cat > "$service_file" <<EOF
[Unit]
Description=Machine ${vmname}

[Service]
Type=simple
ExecStart=${HOME}/.dotfiles/bash/.local/bin/dot machine ${vmname} start
ExecStop=${HOME}/.dotfiles/bash/.local/bin/dot machine ${vmname} stop

[Install]
WantedBy=default.target
EOF

  if ! notify-send "Exported" "${service_name}" > /dev/null 2>&1; then
    echo "Exported" ${service_name}
  fi
  systemctl --user daemon-reload
}
