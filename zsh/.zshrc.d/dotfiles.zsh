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

# Temporary including the old installation method
_dotoldinstall() {
  APTPKGS=("git" "zsh" "stow" "vim" "tmux" "fzf" "jq" "powerline")
  RPMPKGS=("git-core" "zsh" "stow" "vim" "tmux" "fzf" "jq" "powerline" "vim-powerline" "tmux-powerline")

  # Crude multi-os installation option
  if [ -x "/usr/bin/apt-get" ]
  then
    sudo apt-get update
    sudo apt-get install -y ${APTPKGS[@]}
  elif [ -x "/usr/bin/dnf" ]
  then
    sudo dnf install -y ${RPMPKGS[@]}
    # allow first-time system install
    export SYSTEM_INSTALL=1
  elif [ -x "/usr/bin/yum" ]
  then
    sudo yum install -y ${RPMPKGS[@]}
  fi

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

if [[ "$0" == *install.sh* ]]; then
  echo "Performing install"
  _dotoldinstall
fi

_dotresource() {
  echo "Resourcing zsh."
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

if [[ $(dotini --get "dotfiles.aliases") == true ]]; then
  alias dot="dotfiles"
  alias dotup="dot up"
fi

if [[ $(dotini --get "dotfiles.autoupdate") == true ]]; then
  dotfiles up
fi
