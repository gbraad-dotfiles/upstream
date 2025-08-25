#!/bin/zsh

rdot() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <user@host[:port]> <command>"
    return 1
  fi 

  local ADDRESS=$1
  shift 1

  # Parse address and port
  local USERHOST PORT
  if [[ "$ADDRESS" == *:* ]]; then
    USERHOST="${ADDRESS%%:*}"
    PORT="${ADDRESS##*:}"
  else
    USERHOST="$ADDRESS"
    PORT=""
  fi

  local COMMAND='
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export TERM=xterm-256color

if command -v dotfiles >/dev/null 2>&1 && typeset -f dotfiles >/dev/null 2>&1; then
 dotfiles source; __ARGS__
else
 if [ ! -d "${HOME}/.dotfiles" ]; then
  git clone https://github.com/gbraad/dotfiles-stable.git ~/.dotfiles --depth 2
 fi
 "${HOME}/.dotfiles/activate.sh" __ARGS__
fi
'
  local COMMAND_TO_SEND="${COMMAND//__ARGS__/$@}"

  local -a SSH_OPTS
  SSH_OPTS=(-X -t -o StrictHostKeyChecking=no)
  [[ -n "$PORT" ]] && SSH_OPTS+=(-p "$PORT")

  ssh ${SSH_OPTS[@]} ${USERHOST} ${COMMAND_TO_SEND}
}

rshell() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <user@host>"
    return 1
  fi 

  rdot $1 zsh
}

rscreen() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <user@host>"
    return 1
  fi 

  rdot $1 screen
}

mdot() {
    local sysname="$1"
    shift 1
    local config_path="$HOME/.config/containers/macadam/machine/qemu/${sysname}.json"

    if [[ ! -f "$config_path" ]]; then
        echo "Config file not found: $config_path"
        return 1
    fi

    # Extract SSH Port and RemoteUsername from JSON
    local port user
    port=$(jq -r '.SSH.Port' "$config_path")
    user=$(jq -r '.SSH.RemoteUsername' "$config_path")

    if [[ "$port" == "null" || "$user" == "null" ]]; then
        echo "Could not extract SSH credentials from $config_path"
        return 1
    fi

    rdot ${user}@localhost:${port} $@
}

mshell() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <sysname>"
    return 1
  fi 

  mdot $1 zsh
}

mscreen() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <sysname>"
    return 1
  fi 

  mdot $1 screen
}


