#!/bin/zsh

devpods_commands=(
  deploy from undeploy status logs shell exec screen apps dot dotfiles playbook tsconnect switch
)

devpods_prefixes() {
  local key="images"
  local output prefixes
  output=($(dotini devenv --list | grep "^${key}\." || true))
  prefixes=(${output//${key}./})
  prefixes=(${prefixes//=*/})
  printf "%s\n" "${prefixes[@]}"
}

devpods_targets() {
  KUBECONFIG=${KUBECONFIG:-${HOME}/.kube/config} kubectl get pods --no-headers 2>/dev/null \
    | awk '$1 ~ /sys$/ {sub(/sys$/, "", $1); print $1 "\t" $3 "\t" $5}'
}

devpods_running_targets() {
  KUBECONFIG=${KUBECONFIG:-${HOME}/.kube/config} kubectl get pods --no-headers 2>/dev/null \
    | awk '$1 ~ /sys$/ && $3 == "Running" {sub(/sys$/, "", $1); print $1 "\t" $3 "\t" $5}'
}

_dev3s_kubectl() {
  KUBECONFIG=${KUBECONFIG:-${HOME}/.kube/config} kubectl "$@"
}

_dev3s_ensure_ts_secret() {
  local kubectl_args=("$@")
  # Skip if secret already exists
  if _dev3s_kubectl "${kubectl_args[@]}" get secret tailscale-authkey &>/dev/null; then
    return 0
  fi
  local TS_KEY=${TAILSCALE_AUTHKEY:-}
  if [[ -z "$TS_KEY" ]]; then
    TS_KEY=$(secrets get tailscale_authkey)
  fi
  if [[ -n "$TS_KEY" ]]; then
    local manifest
    manifest=$(_dev3s_kubectl "${kubectl_args[@]}" create secret generic tailscale-authkey \
      --from-literal=TS_AUTHKEY="${TS_KEY}" \
      --dry-run=client -o yaml)
    echo "$manifest" | _dev3s_kubectl "${kubectl_args[@]}" apply -f -
  else
    echo "warning: tailscale_authkey not available — pod will start without Tailscale"
  fi
}

_dev3s_apply_pod() {
  local sysname=$1 image=$2 image_user=$3 host=$4
  shift 4
  local kubectl_args=("$@")

  _dev3s_kubectl "${kubectl_args[@]}" apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${sysname}
  labels:
    app: ${sysname}
spec:
  hostname: ${host}-${sysname}
  containers:
  - name: ${sysname}
    image: ${image}
    imagePullPolicy: Always
    securityContext:
      privileged: true
    env:
    - name: TS_AUTHKEY
      valueFrom:
        secretKeyRef:
          name: tailscale-authkey
          key: TS_AUTHKEY
          optional: true
    volumeMounts:
    - name: cgroup
      mountPath: /sys/fs/cgroup
    - name: projects
      mountPath: /home/${image_user}/Projects
    - name: documents
      mountPath: /home/${image_user}/Documents
    - name: downloads
      mountPath: /home/${image_user}/Downloads
    - name: tun
      mountPath: /dev/net/tun
  volumes:
  - name: cgroup
    hostPath:
      path: /sys/fs/cgroup
      type: Directory
  - name: projects
    hostPath:
      path: ${HOME}/Projects
      type: DirectoryOrCreate
  - name: documents
    hostPath:
      path: ${HOME}/Documents
      type: DirectoryOrCreate
  - name: downloads
    hostPath:
      path: ${HOME}/Downloads
      type: DirectoryOrCreate
  - name: tun
    hostPath:
      path: /dev/net/tun
      type: CharDevice
EOF
}

dev3s() {
  local KUBECTL_ARGS=()
  [[ -n "${DEV3S_CONTEXT:-}" ]] && KUBECTL_ARGS+=("--context=${DEV3S_CONTEXT}")

  # No args: list all *sys pods on the cluster
  if [[ $# -eq 0 ]]; then
    _dev3s_kubectl "${KUBECTL_ARGS[@]}" get pods --no-headers \
      | awk '$1 ~ /sys$/ {printf "%-30s %-12s %s\n", $1, $3, $5}'
    return 0
  fi

  # Top-level: dev3s switch [<context>]
  if [[ $1 == "switch" ]]; then
    if [[ -n "${2:-}" ]]; then
      export DEV3S_CONTEXT=$2
      echo "dev3s: switched to context '${DEV3S_CONTEXT}'"
    else
      # List available contexts and pick with fzf if available
      local contexts
      contexts=$(kubectl config get-contexts --no-headers -o name 2>/dev/null)
      if [[ -z "$contexts" ]]; then
        echo "dev3s: no contexts found in kubeconfig"
        return 1
      fi
      local picked
      if command -v fzf &>/dev/null; then
        picked=$(echo "$contexts" | fzf --prompt="context> " --height=10)
      else
        echo "$contexts" | nl -ba
        printf "pick context: "
        read -r picked
      fi
      [[ -z "$picked" ]] && return 0
      export DEV3S_CONTEXT=$picked
      echo "dev3s: switched to context '${DEV3S_CONTEXT}'"
    fi
    return 0
  fi

  if [[ $# -lt 2 ]]; then
    echo "Usage: dev3s switch <cluster>"
    echo "       dev3s <prefix> <command> [args...]"
    echo "Commands: deploy from undeploy status logs exec shell tsconnect"
    [[ -n "${DEV3S_CONTEXT:-}" ]] && echo "Active context: ${DEV3S_CONTEXT}"
    return 1
  fi

  local PREFIX=$1
  local COMMAND=$2
  local SUFFIX="sys"
  local SYSNAME=${PREFIX}${SUFFIX}
  shift 2

  # deploy/from accept an optional one-shot cluster override as first arg
  if [[ "$COMMAND" == "deploy" || "$COMMAND" == "from" ]]; then
    if [[ -n "${1:-}" && "$1" != -* && -z "$(dotini devenv --get "images.${1}" 2>/dev/null)" ]]; then
      KUBECTL_ARGS=("--context=${1}")
      shift
    fi
  fi

  local IMAGE=$(dotini devenv --get "images.${PREFIX}")
  if [[ -z "$IMAGE" ]]; then
    echo "error: unknown devenv prefix '${PREFIX}'"
    return 1
  fi

  local IMAGE_USER=$(dotini devenv --get devenv.user)
  local HOST=$(hostname)

  case "$COMMAND" in
    "deploy")
      _dev3s_ensure_ts_secret "${KUBECTL_ARGS[@]}"
      _dev3s_apply_pod "${SYSNAME}" "${IMAGE}" "${IMAGE_USER}" "${HOST}" "${KUBECTL_ARGS[@]}"
      ;;

    "from")
      local FROM_PREFIX=${1:-}
      if [[ -z "$FROM_PREFIX" ]]; then
        echo "error: dev3s ${PREFIX} from <image-prefix>"
        return 1
      fi
      local FROM_IMAGE=$(dotini devenv --get "images.${FROM_PREFIX}")
      if [[ -z "$FROM_IMAGE" ]]; then
        echo "error: unknown devenv prefix '${FROM_PREFIX}'"
        return 1
      fi
      _dev3s_ensure_ts_secret "${KUBECTL_ARGS[@]}"
      _dev3s_apply_pod "${SYSNAME}" "${FROM_IMAGE}" "${IMAGE_USER}" "${HOST}" "${KUBECTL_ARGS[@]}"
      ;;

    "undeploy")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" delete pod ${SYSNAME} --ignore-not-found
      ;;

    "status")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" get pod ${SYSNAME}
      ;;

    "logs")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" logs ${SYSNAME} "$@"
      ;;

    "exec")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- "$@"
      ;;

    "shell")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- \
        sudo -i -u ${IMAGE_USER} zsh
      ;;

    "tsconnect")
      local LAST3=${HOST: -3}
      local TS_KEY=${TAILSCALE_AUTHKEY:-}
      [[ -z "$TS_KEY" ]] && TS_KEY=$(secrets get tailscale_authkey 2>/dev/null) || true
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- \
        tailscale up --auth-key "${TS_KEY}" --hostname ${SYSNAME}-${LAST3} \
        --operator ${IMAGE_USER} --ssh
      ;;

    "screen")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- \
        sudo -i -u ${IMAGE_USER} zsh -c "dotfiles source; screen -xR"
      ;;

    "apps")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- \
        sudo -i -u ${IMAGE_USER} zsh -c "dotfiles source; app $*"
      ;;

    "dot")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- \
        sudo -i -u ${IMAGE_USER} zsh -c "dotfiles source; export DISPLAY=:0; $*"
      ;;

    "dotfiles")
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- \
        sudo -i -u ${IMAGE_USER} dotfiles "$@"
      ;;

    "playbook")
      local playbook_file=""
      for arg in "$@"; do
        if [[ "$arg" == *.yml || "$arg" == *.yaml ]]; then
          playbook_file="$arg"
        fi
      done
      if [[ -z "$playbook_file" || ! -f "$playbook_file" ]]; then
        echo "error: playbook file not found in arguments"
        return 1
      fi
      local remote_file="/tmp/$(basename ${playbook_file})"
      cat "${playbook_file}" | _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -i ${SYSNAME} -- \
        sh -c "cat > '${remote_file}'"
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -it ${SYSNAME} -- \
        ansible-playbook -i localhost, -c local "${remote_file}"
      _dev3s_kubectl "${KUBECTL_ARGS[@]}" exec -i ${SYSNAME} -- \
        rm -f "${remote_file}"
      ;;

    *)
      echo "Unknown command: dev3s ${PREFIX} ${COMMAND}"
      return 1
      ;;
  esac
}
