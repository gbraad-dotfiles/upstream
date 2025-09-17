#!/bin/zsh

if [[ $(dotini service --get "service.aliases") == true ]]; then
  alias uc="app userctl shared --evaluate; app userctl"
fi

