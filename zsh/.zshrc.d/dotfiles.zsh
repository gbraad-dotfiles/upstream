#!/bin/zsh

# this is to make this work with the restricted bash from Debian
dotini() {
  local config_name="$1"
  shift

  local config_file="${HOME}/.config/dotfiles/${config_name}.ini"
  if [ ! -f "$config_file" ]; then
    config_file="${HOME}/.dotfiles/config/.config/dotfiles/${config_name}.ini"
  fi
  if [ ! -f "$config_file" ]; then
    echo "Config file not found: $config_file"
    return 1
  fi

  git config -f "$config_file" "$@"
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
  stowlist=$(dotini dotfiles --list | grep '^stow\.' | awk -F '=' '$2 == "true" {print $1}' | sed 's/^stow\.//g')
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
    echo "sudo"
  fi
}

_dotpackageinstall_apt() {
  echo "Updating package list and installing packages..."
  # Get the appropriate command prefix
  CMD_PREFIX=$(get_cmd_prefix)

  "${CMD_PREFIX}" apt-get update
  "${CMD_PREFIX}" apt-get install -y \
    git zsh stow vim tmux screen fzf jq \
    powerline
}

_dotpackageinstall_dnf() {
  echo "Installing packages..."
  # Get the appropriate command prefix
  CMD_PREFIX=$(get_cmd_prefix)

  "${CMD_PREFIX}" dnf install -y \
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
  # Disable message
  #if [[ "$DOTFILES_SOURCED_FROM_SOURCE_SH" == 0 || "$DOTFILES_SOURCED_FROM_SOURCE_SH" == false ]]; then
  #  echo "Resourcing zsh."
  #fi
  if [ -d ${HOME}/.zshrc.d ]; then
    for file in ${HOME}/.zshrc.d/*.?sh; do
      source $file
    done
  # allow dotfiles to function without being installed (dot-command)
  elif [ -d ${HOME}/.dotfiles/zsh/.zshrc.d ]; then
    for file in ${HOME}/.dotfiles/zsh/.zshrc.d/*.?sh; do
      source $file
    done
  fi
}

_dotdestow() {
  echo "Unloading ..."
  if [ -d ${HOME}/.zshrc.d ] && [ "$1" != "-f" ] || [ "$1" != "--force" ]; then
    rm -rf ${HOME}/.zshrc.d
  fi

  cd ~/.dotfiles

  stowlist=$(find . -maxdepth 1 -type d ! -name '.*' ! -name '*.*' -exec basename {} \;)
  for destow in $stowlist; do
    stow -D $(echo "$destow" | xargs)
  done

  cd - > /dev/null
}

_dotrestow() {
  # Only run if ~/.config/dotfiles/ is a symlink
  if [ ! -L "${HOME}/.config/dotfiles" ] && [ "$1" != "-f" ] && [ "$1" != "--force" ]; then
    echo "Aborting: ~/.config/dotfiles does not exist"
    return 1
  fi

  echo "Restowing ..."
  cd ~/.dotfiles

  # (re)stow
  stow -R config

  stowlist=$(dotini dotfiles --list | grep '^stow\.' | awk -F '=' '$2 == "true" {print $1}' | sed 's/^stow\.//g')
  echo "$stowlist" | while IFS= read -r tostow; do
    stow -R "$tostow"
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
 
  _dotrestow 
  _dotresource
 
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
  shift

  case "$COMMAND" in
    "up" | "update")
      _dotupdate
      ;;
    "in" | "install")
      _dotinstall
      ;;
    "source" | "resource")
      export DOTFILES_SOURCED_FROM_SOURCE_SH=0
      _dotresource
      ;;
    "reset")
      _dotreset
      ;;
    "stow" | "restow")
      _dotrestow ${1:-}   # allow -f|--force
      ;;
    "unstow" | "destow" | "unload")
      _dotdestow ${1:-}   # allow -f|--force
      ;;
    "switch" | "upstream")
      _dotupstream
      ;;
    "cd")
      cd ${HOME}/.dotfiles
      ;;
    "dot")
      ${HOME}/.dotfiles/activate.sh $@
      ;;
    "paths")
      source ~/.dotfiles/zsh/.zshrc.d/paths.zsh
      ;;
    "screen")
      dotfiles dot screen
      ;;
    # subcommands
    "apps")
      dotfiles dot apps $@
      ;;
    "secrets")
      dotfiles dot secrets $@
      ;;
    "devenv")
      dotfiles dot devenv $@
      ;;
    "devbox")
      dotfiles dot devbox $@
      ;;
    "proxy")
      dotfiles dot proxy $@
      ;;
    "machine")
      dotfiles dot machine $@
      ;;
    *)
      echo "Unknown command: $0 $COMMAND"
      ;;
  esac
}

# The file *dotfiles.sh exists to enable to dotfiles command
# Unlike the next checks, it does not perform any action

if [ "$(expr "$0" : '.*install.sh')" -gt 0 ]; then
  echo "Performing install"
  _dotoldinstall
fi

if [ "$(expr "$0" : '.*source.sh')" -gt 0 ]; then
  #export DOTFILES_SOURCED_FROM_SOURCE_SH=1
  _dotresource
fi

if [ "$(dotini dotfiles --get "dotfiles.aliases")" = true ]; then
  alias dot="${HOME}/.dotfiles/activate.sh"
fi

if [ "$(dotini dotfiles --get "dotfiles.autoupdate")" = true ]; then
  dotup
fi

dotup() {

   if [ "$(dotini dotfiles --get "dotup.dotfiles")" = true ]; then
     dotfiles update
   fi

   if [ "$(dotini dotfiles --get "dotup.apps")" = true ]; then
     apps list update
   fi

   if [ "$(dotini dotfiles --get "dotup.secrets")" = true ]; then
     # TODO: make sure dotini exists as a reusable function
     # The path is defined in secrets.ini
     if [ -d "${HOME}/.dotsecrets" ]; then
       secrets update
     fi
   fi

}
