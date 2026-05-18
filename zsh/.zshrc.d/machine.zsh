#!/bin/zsh

machine_commands=(
  status create start stop download remove from switch apps playbook tsconnect export service-install copy-id shell
)

machine_runtime() {
  local rt
  rt=$(dotini machine --get machine.runtime 2>/dev/null)
  rt="${rt:-macadam}"
  # normalize: both "lima" and "limactl" mean the same runtime
  [[ "$rt" == "lima" ]] && rt="limactl"
  echo "$rt"
}

machine_credentials() {
  if (( $# != 4 )); then
    print -u2 "Usage: machine_credentials <machine-name> <var_port> <var_user> <var_identity>"
    return 2
  fi

  case "$(machine_runtime)" in
    "limactl") _machine_credentials_lima "$@" ;;
    *) _machine_credentials_macadam "$@" ;;
  esac
}

_machine_credentials_macadam() {
  local sysname=$1 port_var=$2 user_var=$3 ident_var=$4
  local config_path="$HOME/.config/containers/macadam/machine/qemu/${sysname}.json"

  [[ -f $config_path ]] || { print -u2 "Config file not found: $config_path"; return 1; }

  # returns: port \t user \t identity
  local line
  if ! line=$(jq -r '[.SSH.Port, .SSH.RemoteUsername, .SSH.IdentityPath] | @tsv' "$config_path"); then
    print -u2 "jq failed reading $config_path"
    return 1
  fi

  local -a parts
  IFS=$'\t' parts=(${=line})

  if (( ${#parts[@]} != 3 )) || [[ $parts[1] == null || $parts[2] == null || $parts[3] == null ]]; then
    print -u2 "Invalid or incomplete SSH info in $config_path"
    return 1
  fi

  printf -v "$port_var"  '%s' "$parts[1]"
  printf -v "$user_var"  '%s' "$parts[2]"
  printf -v "$ident_var" '%s' "$parts[3]"
}

_machine_credentials_lima() {
  local sysname=$1 port_var=$2 user_var=$3 ident_var=$4

  # SSH column from limactl list is "127.0.0.1:PORT" when running, "-" otherwise
  local ssh_info
  ssh_info=$(limactl list 2>/dev/null | awk -v n="$sysname" 'NR>1 && $1==n{print $3}')

  if [[ -z "$ssh_info" || "$ssh_info" == "-" ]]; then
    print -u2 "Lima: no SSH info for $sysname (is it running?)"
    return 1
  fi

  local port="${ssh_info##*:}"

  local user
  user=$(dotini machine --get machine.user 2>/dev/null)
  [[ -z "$user" ]] && user="$USER"

  local identity
  identity=$(dotini machine --get machine.identitypath 2>/dev/null)
  identity="${identity/#\~/$HOME}"
  [[ -z "$identity" ]] && identity="$HOME/.ssh/id_lima"

  printf -v "$port_var"  '%s' "$port"
  printf -v "$user_var"  '%s' "$user"
  printf -v "$ident_var" '%s' "$identity"
}

machine_build() {
  if ! app machinefile check; then
    app machinefile install
  fi

  local sysname=$1
  local filename=$2

  local mport muser midentity
  local userpasswd
  userpasswd="$(dotini machine --get machine.userpasswd)"
  rootpasswd="$(dotini machine --get machine.rootpasswd)"
  machine_credentials "${sysname}" mport muser midentity

  if [[ -f "${filename}-pre" ]]; then
    machinefile --host localhost --port ${mport} --user ${muser} --key ${midentity} --arg=ROOT_PASSWD=${rootpasswd} "${filename}-pre" .
  fi

  machinefile --host localhost --port ${mport} --user root --password ${rootpasswd} --arg=USER_PASSWD=${userpasswd} ${filename} .

  if [[ -f "${filename}-post" ]]; then
    machinefile --host localhost --port ${mport} --user ${muser} --key ${midentity} --arg=USER_PASSWD=${userpasswd} "${filename}-post" .
  fi

}

machine_deployments() {
  local key="images"
  local output targets
  output=($(dotini machine --list | grep "^${key}\." || true))
  targets=(${output//${key}./})
  targets=(${targets//=*/})
  printf "%s\n" "${targets[@]}"
}

machine_prefixes() {
  local key="disks"
  local output prefixes
  output=($(dotini machine --list | grep "^${key}\." || true))
  prefixes=(${output//${key}./})
  prefixes=(${prefixes//=*/})
  printf "%s\n" "${prefixes[@]}"
}

machine_targets() {
  machine_status | awk '{print $1 "\t" $2 }'
}

machine_running_targets() {
  machine_status | awk '$2 == "Running" {print $1 "\t[" $2 "]"}'
}

machine_status() {
  case "$(machine_runtime)" in
    "limactl") _machine_status_lima ;;
    *) _machine_status_macadam ;;
  esac
}

_machine_status_macadam() {
  macadam list | awk '
  NR==1 {
    # Find header indices
    for(i=1;i<=NF;i++) {
        if($i=="NAME") name_idx=i;
    }
    next
  }
  {
    name = gensub(/^machine-/, "", "g", $(name_idx));
    status = ($0 ~ /Currently running/) ? "Running" : "Stopped";
    print name "\t" status;
  }' | column -t
}

_machine_status_lima() {
  limactl list 2>/dev/null | awk '
  NR==1 { next }
  /^machine-/ {
    name = gensub(/^machine-/, "", "g", $1);
    status = ($2 == "Running") ? "Running" : "Stopped";
    print name "\t" status;
  }' | column -t
}

machine_lima_create() {
  local sysname=$1 disk_file=$2 cpus=$3 memory=$4 disksize=$5 user=$6 identity=$7

  local missing=()
  [[ -z "$sysname" ]]   && missing+=("sysname")
  [[ -z "$disk_file" ]] && missing+=("disk_file")
  [[ -z "$cpus" ]]      && missing+=("cpus")
  [[ -z "$memory" ]]    && missing+=("memory")
  [[ -z "$disksize" ]]  && missing+=("disksize")
  [[ -z "$user" ]]      && missing+=("user")
  [[ -z "$identity" ]]  && missing+=("identity")
  if (( ${#missing[@]} > 0 )); then
    print -u2 "machine_lima_create: missing required values: ${(j:, :)missing}"
    return 1
  fi

  [[ -f "$disk_file" ]] || { print -u2 "Disk image not found: $disk_file"; return 1; }

  local tmpyaml
  tmpyaml=$(mktemp /tmp/lima-${sysname}-XXXXXX.yaml)
  cat > "$tmpyaml" <<LIMAYAML
vmType: "qemu"
plain: true
cpus: ${cpus}
memory: "${memory}MiB"
disk: "${disksize}GiB"
images:
  - location: "${disk_file}"
user:
  name: "${user}"
ssh:
  localPort: 0
  loadDotSSHPubKeys: true
mounts: []
LIMAYAML
  limactl create --tty=false --name "${sysname}" "$tmpyaml"
  local rc=$?
  rm -f "$tmpyaml"
  return $rc
}

machine() { 
  local RUNTIME=$(machine_runtime)

  if [[ $RUNTIME == "limactl" ]]; then
    if ! app lima check; then
      app lima install
    fi
  else
    if ! app macadam check; then
      app macadam install
    fi
  fi

  if [ $# -lt 2 ]; then
    machine_status
    return 0
  fi

  local PREFIX=$1
  local SYSNAME="machine-${PREFIX}"
  local COMMAND=$2
  shift 2

  local DISKFOLDER=$(dotini machine --get machine.diskfolder)
  DISKFOLDER="${DISKFOLDER/#\~/$HOME}"
  local IDENTITYPATH=$(dotini machine --get machine.identitypath)
  IDENTITYPATH="${IDENTITYPATH/#\~/$HOME}"
  local HELPERPATH=$(dotini machine --get machine.helperpath)
  HELPERPATH="${HELPERPATH/#\~/$HOME}"
  local START_SHELL=$(dotini devenv --get devenv.shell)
  local IMAGE_USER=$(dotini machine --get machine.user)
  
  if [[ -n "${HELPERPATH}" && -e "${HELPERPATH}" ]]; then
    export CONTAINERS_HELPER_BINARY_DIR=${HELPERPATH}
  fi

  # ensuere folder exists
  if [ ! -d "${DISKFOLDER}" ]; then
    mkdir -p "${DISKFOLDER}"
  fi

  
  local START_ARGS=()
  local INIT_ARGS=(
    "--cpus=$(dotini machine --get machine.vcpus)"
    "--memory=$(dotini machine --get machine.memory)"
    "--disk-size=$(dotini machine --get machine.disksize)"
    "--username=${IMAGE_USER}"
    "--ssh-identity-path=${IDENTITYPATH}"
  )
  local FIRMWARE=$(dotini machine --get "firmware.${PREFIX}" 2>/dev/null || true)
  if [[ -n "${FIRMWARE}" ]]; then
    INIT_ARGS+=("--firmware=${FIRMWARE}")
  fi
  if [[ "$(dotini machine --get machine.debug)" == "true" ]]; then
    local debug="--log-level=debug"
    START_ARGS+=($debug)
    INIT_ARGS+=($debug)
  fi

  case "$COMMAND" in
    "exists")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl list 2>/dev/null | awk 'NR>1{print $1}' | grep -q "^${SYSNAME}$"
        return $?
      else
        return $(macadam list | grep -q -E "${SYSNAME} ")
      fi
      ;;
    "status")
      machine_targets | awk -v prefix="$PREFIX" '$1 == prefix {print $2}'
      ;;
    "download")
      local disk_url
      disk_url="$(dotini machine --get disks.${PREFIX})"
      if [[ -z "$disk_url" ]]; then
        print -u2 "No disk image configured for prefix '${PREFIX}' in [disks]"
        return 1
      fi
      download "$disk_url" "${DISKFOLDER}/${PREFIX}.qcow2"
      ;;
    "system" | "create" | "init")
      if [[ ! -f "${DISKFOLDER}/${PREFIX}.qcow2" ]]; then
        machine ${PREFIX} download
      fi
      if [[ $RUNTIME == "limactl" ]]; then
        machine_lima_create "${SYSNAME}" "${DISKFOLDER}/${PREFIX}.qcow2" \
          "$(dotini machine --get machine.vcpus)" \
          "$(dotini machine --get machine.memory)" \
          "$(dotini machine --get machine.disksize)" \
          "${IMAGE_USER}" "${IDENTITYPATH}"
      else
        macadam init --name "${SYSNAME}" ${INIT_ARGS[@]} "${DISKFOLDER}/${PREFIX}.qcow2"
      fi
      ;;
    "restart" | "reboot")
      machine ${PREFIX} stop
      machine ${PREFIX} start
      ;;
    "start")
      if ! machine ${PREFIX} exists; then
        machine ${PREFIX} create
      fi
      if [[ $RUNTIME == "limactl" ]]; then
        limactl start --tty=false "${SYSNAME}"
      else
        macadam start ${START_ARGS[@]} "${SYSNAME}"
      fi
      ;;
    "stop")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl stop "${SYSNAME}"
      else
        macadam stop "${SYSNAME}"
      fi
      ;;
    "kill" | "rm" | "remove")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl delete --force "${SYSNAME}"
      else
        macadam rm -f "${SYSNAME}"
      fi
      ;;
    "console" | "ssh")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl shell "${SYSNAME}"
      else
        macadam ssh "${SYSNAME}"
      fi
      ;;
    "root" | "su")
      machine ${PREFIX} sudo ${START_SHELL} 
      ;;
    "sudo")
      machine ${PREFIX} exec sudo $@
      ;;
    "exec" | "user")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl shell "${SYSNAME}" -- "$@"
      else
        macadam ssh "${SYSNAME}" "$@"
      fi
      ;;
    "systemctl" | "systemd")
      machine ${PREFIX} exec sudo systemctl $@
      ;;
    "apps")
      machine ${PREFIX} dot apps $*
      ;;
    "dot")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl shell "${SYSNAME}" -- bash -c "dotfiles source; export DISPLAY=:0; $*"
      else
        mdot ${SYSNAME} "dotfiles source; export DISPLAY=:0; $*"
      fi
      ;;
    "copyid" | "copy-id")
      if [[ $RUNTIME == "limactl" ]]; then
        print -u2 "Lima: SSH key is injected during image build; copyid is not needed."
      else
        mcopyid ${SYSNAME}
      fi
      ;;
    "shell")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl shell "${SYSNAME}"
      else
        mshell ${SYSNAME}
      fi
      ;;
    "screen")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl shell "${SYSNAME}" -- screen
      else
        mscreen ${SYSNAME}
      fi
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
      if [[ $RUNTIME == "limactl" ]]; then
        playbook_remote limactl ${SYSNAME} $@
      else
        playbook_remote macadam ${SYSNAME} $@
      fi
      ;; # <filename> <...> 
    "from")
      if machine ${PREFIX} exists; then
        echo "Machine ${PREFIX} already exists"
        return 1
      fi

      # use $1 as prefix value for the image
      if [[ ! -f "${DISKFOLDER}/$1.qcow2" ]]; then
        machine $1 download
      fi
      if [[ $RUNTIME == "limactl" ]]; then
        machine_lima_create "${SYSNAME}" "${DISKFOLDER}/$1.qcow2" \
          "$(dotini machine --get machine.vcpus)" \
          "$(dotini machine --get machine.memory)" \
          "$(dotini machine --get machine.disksize)" \
          "${IMAGE_USER}" "${IDENTITYPATH}"
      else
        macadam init --name "${SYSNAME}" "${INIT_ARGS[@]}" "${DISKFOLDER}/$1.qcow2"
      fi

      machine ${PREFIX} start
      ;;
    "from-image")
      if machine ${PREFIX} exists; then
        echo "Machine ${PREFIX} already exists"
        return 1
      fi

      if [[ $RUNTIME == "limactl" ]]; then
        machine_lima_create "${SYSNAME}" "$1" \
          "$(dotini machine --get machine.vcpus)" \
          "$(dotini machine --get machine.memory)" \
          "$(dotini machine --get machine.disksize)" \
          "${IMAGE_USER}" "${IDENTITYPATH}"
      else
        macadam init --name "${SYSNAME}" "${INIT_ARGS[@]}" "$1"
      fi

      machine ${PREFIX} start
      ;;
    "build")
      local SUBCOMMAND=$2
      case "$SUBCOMMAND" in
        "from")
          machine ${PREFIX} from "$3" || true
          ;;
        "from-image")
          machine ${PREFIX} from-image "$3" || true
          ;;
      esac

      local vmstate=$(machine ${PREFIX} status)
      if [ "${vmstate}" = "Stopped" ]; then
        machine ${PREFIX} start || true
      fi

      echo "Waiting for VM to be ready..."
      local mport muser midentity
      machine_credentials "${SYSNAME}" mport muser midentity
      local waited=0 timeout=300
      until ssh -i "${midentity}" -p "${mport}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes "${muser}@localhost" true 2>/dev/null; do
        if (( waited >= timeout )); then
          echo "Timed out waiting for VM SSH"
          return 1
        fi
        sleep 2
        (( waited += 2 ))
      done

      machine_build "${SYSNAME}" $@ || { echo "Machine build failed"; return 1; }
      echo "Machine build succeeded"
      ;;
    "export")
      if ! machine ${PREFIX} exists; then
        echo "Machine ${PREFIX} does not exist"
        return 1
      fi

      local vmstate=$(machine ${PREFIX} status)
      if [ "${vmstate}" = "Running" ]; then
        machine ${PREFIX} stop
      fi

      local imagepath
      if [[ $RUNTIME == "limactl" ]]; then
        local lima_dir
        lima_dir=$(limactl list --json 2>/dev/null | jq -r --arg n "${SYSNAME}" '.[] | select(.name == $n) | .dir // empty')
        [[ -z "$lima_dir" ]] && { print -u2 "Could not find lima instance dir for ${SYSNAME}"; return 1; }
        imagepath="${lima_dir}/basedisk"
        [[ ! -f "$imagepath" ]] && imagepath="${lima_dir}/diffdisk"
      else
        local config_path="$HOME/.config/containers/macadam/machine/qemu/${SYSNAME}.json"
        [[ -f $config_path ]] || { print -u2 "Config file not found: $config_path"; return 1; }
        imagepath=$(jq -r '.ImagePath.Path' $config_path)
      fi

      if [[ "$1" = /* || "$1" = ./* || "$1" = ../* || "$1" = ~* ]]; then
        target="$1"
      else
        target="${DISKFOLDER}/$1"
      fi

      # If target does not end with .qcow2, add it
      if [[ "$target" != *.qcow2 ]]; then
        target="${target}.qcow2"
      fi

      cp "$imagepath" "$target"
      echo "Copied to $target"
      ;;
    "tsconnect")
      local LAST3=${HOSTNAME: -3}
      secrets var tailscale_authkey
      machine ${PREFIX} sudo tailscale up --auth-key "${TAILSCALE_AUTHKEY}" --hostname ${SYSNAME}-${LAST3} --operator ${IMAGE_USER} --ssh
      ;;
    "service-install")
      machine-service-install ${PREFIX}
      ;;
    "service")
      if [[ $RUNTIME == "limactl" ]]; then
        limactl start --tty=false "${SYSNAME}" 2>/dev/null || true
        while [[ "$(limactl list 2>/dev/null | awk -v n="${SYSNAME}" 'NR>1 && $1==n{print $2}')" == "Running" ]]; do
          sleep 5
        done
      else
        macadam start ${SYSNAME} -q
        while pgrep -f "qemu-system.*${SYSNAME}" >/dev/null; do
          #echo "running"
          sleep 5
        done
      fi
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}

if [[ $(dotini machine --get "machine.aliases") == true ]]; then
  alias m="machine"
  alias ms="app machines"
  alias mcn="machine"
fi

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

machine-service-install() {
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
ExecStart=${HOME}/.dotfiles/bash/.local/bin/dot machine ${vmname} service
ExecStop=${HOME}/.dotfiles/bash/.local/bin/dot machine ${vmname} stop

[Install]
WantedBy=default.target
EOF

  if ! notify-send "Exported" "${service_name}" > /dev/null 2>&1; then
    echo "Exported" ${service_name}
  fi
  systemctl --user daemon-reload
}
