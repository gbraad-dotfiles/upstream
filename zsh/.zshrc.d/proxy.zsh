#!/bin/zsh

CONFIG="${HOME}/.proxy"
alias proxyini="git config -f $CONFIG"

proxyselect() {
  echo $(proxyini --list | grep '^servers\.' | sed 's/^servers\.//g' | cut -d '=' -f 1 | sort | fzf)
}

proxy() {

  local PREFIX=$1

  if [ -z "$PREFIX" ]; then
    PREFIX=$(proxyselect)
  fi

  if [ -z "$PREFIX" ]; then
    echo "Clearing proxy setting"
    unset http_proxy
    unset https_proxy
    return
  fi

  local SERVER=$(proxyini --get servers.${PREFIX})

  export http_proxy=${SERVER}
  export https_proxy=${SERVER}

  echo "Proxy settings"
  set | grep -E "http_proxy|https_proxy"
}

if [[ $(proxyini --get "proxy.aliases") == true ]]; then
  alias p="proxy"
fi
