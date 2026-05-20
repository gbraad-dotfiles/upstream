# Used for all Zsh invocations (including scripts)

# runs before zprofile and zshrc
# ensuer dotfiles function is available
source ${HOME}/.dotfiles/dotfiles.sh
dotfiles paths

# Redirect zcompdump out of ZDOTDIR to avoid conflicts with stow
export ZSH_COMPDUMP="${HOME}/.cache/zsh/.zcompdump-${HOST}-${ZSH_VERSION}"
