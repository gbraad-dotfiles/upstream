#!/bin/zsh

_installnix() {
  sh <(curl -L https://nixos.org/nix/install)
}
alias install-nix=_installnix

