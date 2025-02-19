#!/bin/zsh

CONFIG="${HOME}/.davfs"
alias davfsini="git config -f ${CONFIG}"

davfs() {
  if [ $# -lt 2 ]; then
    echo "Usage: $0 <prefix> <command> [args...]"
    return 1
  fi

  local PREFIX=$1
  local COMMAND=$2
  shift 2

  case "$COMMAND" in
    "browse")
      cadaver $(davfsini --get "hosts.${PREFIX}")
      ;;
    "mount")
      # mount -t davfs2
      ;;
    "tsshare")
      tailscale drive share Projects ${HOME}/Projects
      tailscale drive share Documents ${HOME}/Documents
      tailscale drive share Downloads ${HOME}/Downloads
      ;;
    *)
      echo "Unknown command: $0 $PREFIX $COMMAND"
      ;;
  esac
}
