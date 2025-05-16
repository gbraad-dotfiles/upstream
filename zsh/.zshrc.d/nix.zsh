#!/bin/zsh

_installnix() {
  sh <(curl -L https://nixos.org/nix/install)
}
alias install-nix=_installnix

if [ -e /var/home/gbraad/.nix-profile/etc/profile.d/nix.sh ]; then
  . /var/home/gbraad/.nix-profile/etc/profile.d/nix.sh;
fi
