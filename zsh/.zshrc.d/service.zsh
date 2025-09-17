#!/bin/zsh

if [[ $(dotini service --get "service.aliases") == true ]]; then
  alias uc="app userctl"
fi

