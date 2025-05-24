#!/bin/zsh
if [[ $- == *i* ]] && [[ -t 0 ]]; then
    printf '\033[6 q\r'
fi

