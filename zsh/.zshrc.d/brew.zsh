#!/bin/zsh

# Bash is required to interpret this script
_installhomebrew() {
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
alias install-homebrew=_installhomebrew

if [ -d "/home/linuxbrew/.linuxbrew" ]; then
  export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew";
  export HOMEBREW_CELLAR="/home/linuxbrew/.linuxbrew/Cellar";
  export HOMEBREW_REPOSITORY="/home/linuxbrew/.linuxbrew/Homebrew";
  fpath[1,0]="/home/linuxbrew/.linuxbrew/share/zsh/site-functions";
  export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin${PATH+:$PATH}";
  [ -z "${MANPATH-}" ] || export MANPATH=":${MANPATH#:}";
  export INFOPATH="/home/linuxbrew/.linuxbrew/share/info:${INFOPATH:-}";
fi
