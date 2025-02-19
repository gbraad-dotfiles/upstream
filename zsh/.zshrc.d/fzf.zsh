#!/bin/zsh

if [[ -r /usr/share/fzf/shell/key-bindings.zsh ]]; then
    source /usr/share/fzf/shell/key-bindings.zsh
    # since package is b0rked?
    if [[ -r /usr/share/zsh/site-functions/fzf ]]; then
        source /usr/share/zsh/site-functions/fzf
    fi
    # even more broken ?
    if [[ -r /usr/share/zsh/site-functions/_fzf ]]; then
        source /usr/share/zsh/site-functions/_fzf
    fi
fi

