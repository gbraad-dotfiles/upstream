#!/bin/zsh

CONFIG="${HOME}/.config/dotfiles/dotfiles"
dotini() {
  git config -f $CONFIG "$@"
}

chown_if_needed() {
  local expected_user="$1"
  local target="$2"
  local current_owner

  if [ -z "$expected_user" ] || [ -z "$target" ]; then
    return 1
  fi

  if [ ! -e "$target" ]; then
    return 2
  fi

  current_owner=$(stat -c '%U' "$target")
  if [ "$current_owner" != "$expected_user" ]; then
    sudo chown -R "$expected_user" "$target"
  fi
}

if [[ $(dotini --get "dotfiles.userdirs") == true ]]; then
  chown_if_needed ${USER} ${HOME}/Projects
  chown_if_needed ${USER} ${HOME}/Documents
  chown_if_needed ${USER} ${HOME}/Downloads

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
