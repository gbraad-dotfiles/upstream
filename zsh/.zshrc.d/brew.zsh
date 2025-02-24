#!/bin/zsh

# Bash is required to interpret this script
_installhomebrew() {
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}
alias install-homebrew=_installhomebrew
