#!/bin/zsh

# Try user Python installs (finds first matching powerline.zsh)
local found=0
local matches=($HOME/.local/lib/python*/site-packages/powerline/bindings/zsh/powerline.zsh(N))
if [[ ${#matches} -gt 0 ]]; then
    export POWERLINE_CONFIG_COMMAND="$HOME/.local/bin/powerline-config"
    source "$matches[1]"
    found=1
fi

# Try root (system pip) Python installs in /usr/local
if (( !found )); then
    matches=(/usr/local/lib/python*/site-packages/powerline/bindings/zsh/powerline.zsh(N))
    if [[ ${#matches} -gt 0 ]]; then
        export POWERLINE_CONFIG_COMMAND="/usr/local/bin/powerline-config"
        source "$matches[1]"
        found=1
    fi
fi

# System-wide or custom installs
if (( !found )) && command -v powerline-daemon &>/dev/null; then
    POWERLINE_ZSH_CONTINUATION=1
    POWERLINE_ZSH_SELECT=1

    # Fedora
    [[ -f /usr/share/powerline/zsh/powerline.zsh ]] && source /usr/share/powerline/zsh/powerline.zsh

    # Debian
    [[ -f /usr/share/powerline/bindings/zsh/powerline.zsh ]] && source /usr/share/powerline/bindings/zsh/powerline.zsh

    # custom local repo
    [[ -f .dotfiles/powerline-local/.local/share/powerline/zsh/powerline.zsh ]] && source .dotfiles/powerline-local/.local/share/powerline/zsh/powerline.zsh
fi
