#!/bin/zsh

proxyselect() {
  echo $(dotini proxy --list | grep '^servers\.' | sed 's/^servers\.//g' | cut -d '=' -f 1 | sort | fzf)
}

proxy() {

  local PREFIX=$1
  local output=$(dotini proxy --get "proxy.outpout")

  if [ -z "$PREFIX" ]; then
    PREFIX=$(proxyselect)
  fi

  if [ -z "$PREFIX" ] || [ "$PREFIX" = "-" ]; then
    if [[ $output == true ]]; then
      echo "Clearing proxy setting"
    fi
    unset http_proxy
    unset https_proxy
    return
  fi

  local SERVER=$(dotini proxy --get servers.${PREFIX})

  export http_proxy="${SERVER}"
  export https_proxy="${SERVER}"
  
  if [[ $output == true ]]; then
    echo "Proxy settings"
    set | grep -E "http_proxy|https_proxy"
  fi
}

if [[ $(dotini proxy --get "proxy.aliases") == true ]]; then
  alias p="proxy"
fi
