# Ensure dotfiles is sourced
if ! whence -w dotfiles > /dev/null 2>&1; then
  source ${HOME}/.dotfiles/dotfiles.sh
fi

if ! whence -w apps > /dev/null 2>&1; then
  #source ${HOME}/.dotfiles/source.sh
  dotfiles source
fi
