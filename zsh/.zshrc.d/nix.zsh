#!/bin/zsh

alias install-nix="app nix install"

if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  . ~/.nix-profile/etc/profile.d/nix.sh;
fi
