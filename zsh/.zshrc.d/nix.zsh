#!/bin/zsh

_installnix() {
  sh <(curl -L https://nixos.org/nix/install)
}
alias install-nix=_installnix

if [ -e ~/.nix-profile/etc/profile.d/nix.sh ]; then
  . ~/.nix-profile/etc/profile.d/nix.sh;
fi
