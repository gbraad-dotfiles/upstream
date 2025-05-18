#!/bin/zsh

CONFIG="${HOME}/.config/dotfiles/dotfiles"
#alias dotini="git config -f $CONFIG"

# this is to make this work with the restricted bash from Debian
dotini() {
  git config -f $CONFIG "$@"
}

_dotinstall() {
  # Personal dotfiles
  git clone https://github.com/gbraad/dotfiles.git ~/.dotfiles --depth 2
  cd ~/.dotfiles
  # TODO: make `oh-my-zsh` optional
  git submodule update --init --progress

  # always
  stow config

  # stow
  stowlist=$(dotini --list | grep '^stow\.' | awk -F '=' '$2 == "true" {print $1}' | sed 's/^stow\.//g')
  for tostow in $stowlist; do
    stow $( echo $tostow | xargs )
  done

  # stow wsl specific stuff
  if grep -qi Microsoft /proc/version; then
    stow wsl
  fi

  # stow cygwin specific stuff
  if [ "$OSTYPE" = "cygwin" ]
  then
    stow cygwin
  fi
}

is_root() {
  [ "$(id -u)" = "0" ]
}

get_cmd_prefix() {
  if is_root; then
    echo ""
  else
    echo "sudo "
  fi
}

_dotpackageinstall_apt() {
  echo "Updating package list and installing packages..."
  # Get the appropriate command prefix
  CMD_PREFIX=$(get_cmd_prefix)

  ${CMD_PREFIX}apt-get update
  ${CMD_PREFIX}apt-get install -y \
    git zsh stow vim tmux screen fzf jq \
    powerline
}

_dotpackageinstall_dnf() {
  echo "Installing packages..."
  # Get the appropriate command prefix
  CMD_PREFIX=$(get_cmd_prefix)

  ${CMD_PREFIX}dnf install -y \
    git-core zsh stow vim tmux screen fzf jq \
    powerline vim-powerline tmux-powerline
  # allow first-time system install
}

_dotpackageinstall() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "Dectected $ID"
  else
    echo "Error: /etc/os-release not found. Unable to determine the operating system."
    return 1
  fi

  case "$ID" in
    "debian" | "ubuntu")
      _dotpackageinstall_apt
      ;;
    "fedora" | "centos" | "rhel" | "almalinux")
      _dotpackageinstall_dnf 
      export SYSTEM_INSTALL=1
      ;;
    *)
      echo "Error: Unsupported operating system $ID."
      if command -v apt-get > /dev/null 2>&1; then
        _dotpackageinstall_apt
      elif command -v dnf > /dev/null 2>&1; then
        _dotpackageinstall_dnf 
      else
        echo "Error: No supported package manager found (apt-get or dnf)."
        return 1
      fi
      ;;
  esac
}

# Temporary including the old installation method
_dotoldinstall() {

  _dotpackageinstall

  # Add missing directory layout
  if [ ! -d "~/.config" ]
  then
    mkdir -p ~/.config
  fi

  mkdir -p ~/.local/bin
  mkdir -p ~/.local/lib/python2.7/site-packages/

  _dotinstall

  echo "Install finished; use \`chsh -s /bin/zsh\` or \`chsh -s /usr/bin/zsh\` to change shell"
}

_dotresource() {
  if [[ -z "$DOTFILES_SOURCED_FROM_SOURCE_SH" ]]; then
    echo "Resourcing zsh."
  fi
  if [ -d $HOME/.zshrc.d ]; then
    for file in $HOME/.zshrc.d/*.?sh; do
      source $file
    done
  fi
}

_dotrestow() {
  echo "Restowing ..."
  cd ~/.dotfiles

  # (re)stow
  stow -R config

  stowlist=$(dotini --list | grep '^stow\.' | awk -F '=' '$2 == "true" {print $1}' | sed 's/^stow\.//g')
  for tostow in $stowlist; do
    stow -R $(echo "$tostow" | xargs)
  done

  cd - > /dev/null
}

_dotupstream() {
  cd ~/.dotfiles

  git remote remove origin
  git remote add origin git@github.com:gbraad-dotfiles/upstream
  git fetch
  git branch --set-upstream-to=origin/main main

  cd - > /dev/null

  _dotupdate
}

_dotreset() {
  echo "Reconciling remotes ..."
  cd ~/.dotfiles

  git stash
  git fetch origin
  git reset --hard origin/main
   
  cd - > /dev/null
}

_dotupdate() {
  echo "Reticulating splines ..."
  cd ~/.dotfiles

  git pull
  # (re)stow and (re)source
  _dotrestow
  _dotresource

  cd - > /dev/null
}

dotfiles() {
  if [ $# -lt 1 ]; then
    echo "Usage: $0 <command> [args...]"
    return 1
  fi

  local COMMAND=$1

  case "$COMMAND" in
    "up" | "update")
      _dotupdate
      ;;
    "in" | "install")
      _dotinstall
      ;;
    "resource")
      _dotresource
      ;;
    "reset")
      _dotreset
      ;;
    "restow")
      _dotrestow
      ;;
    "switch" | "upstream")
      _dotupstream
      ;;
    *)
      echo "Unknown command: $0 $COMMAND"
      ;;
  esac
}

if [ "$(expr "$0" : '.*install.sh')" -gt 0 ]; then
  echo "Performing install"
  _dotoldinstall
fi

if [ "$(expr "$0" : '.*source.sh')" -gt 0 ]; then
  export DOTFILES_SOURCED_FROM_SOURCE_SH=1
  _dotresource
fi

if [ "$(dotini --get "dotfiles.aliases")" = true ]; then
  alias dot="dotfiles"
  alias dotup="dot up"
fi

if [ "$(dotini --get "dotfiles.autoupdate")" = true ]; then
  dotfiles up
fi
