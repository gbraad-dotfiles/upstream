#!/bin/zsh
HOSTNAME=$(cat ~/.hostname 2>/dev/null | tr -d '[:space:]')

if [ -z "$HOSTNAME" ]; then
  HOSTNAME=$(cat /etc/hostname 2>/dev/null | tr -d '[:space:]')
fi

if [ -z "$HOSTNAME" ]; then
  HOSTNAME=$(hostname 2>/dev/null | tr -d '[:space:]')
fi

#if [ -z "$HOSTNAME" ]; then
#  HOSTNAME=$(ip addr show eth0 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
#fi

if [ -z "$HOSTNAME" ]; then
  HOSTNAME="unknown"
fi

export HOSTNAME
