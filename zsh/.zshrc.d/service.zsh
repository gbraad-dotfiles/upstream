#!/bin/zsh

if [[ $(dotini service --get "service.aliases") == true ]]; then
  alias uc="apps userctl"
fi

