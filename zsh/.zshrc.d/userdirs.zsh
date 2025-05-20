#!/bin/zsh

CONFIG="${HOME}/.config/dotfiles/dotfiles"
dotini() {
  git config -f $CONFIG "$@"
}

if [[ $(dotini --get "dotfiles.userdirs") == true ]]; then
  mkdir -p ${HOME}/Projects

  if which xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update --force
  else 
    mkdir -p ${HOME}/Documents
    mkdir -p ${HOME}/Downloads
  fi
  mkdir -p ${HOME}/Documents/Notebooks
  mkdir -p ${HOME}/Documents/Vaults

fi
