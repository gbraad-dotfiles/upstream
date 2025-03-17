#!/bin/zsh

podsysctl() {

   if [ $# -lt 2 ]; then
       echo "Usage: podsysctl <name> <command> [args ...]"
       return 1
   fi

   name=$1
   shift 1
   podman exec -it ${name} systemctl $@

}

tailsysctl() {

   if [ $# -lt 2 ]; then
       echo "Usage: tailsysctl <name> <command> [args ...]"
       return 1
   fi

   name=$1
   shift 1
   tailscale ssh ${USER}@${name} systemctl $@

}

sysctl() {

   systemctl status $(systemctl list-units --type service --no-pager --no-legend | fzf)

}

sysjson() {

   systemctl list-units $1 --all --output=json --no-pager

}
