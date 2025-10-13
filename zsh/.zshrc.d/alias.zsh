#!/bin/zsh

# colorized cat
alias ccat='pygmentize -g -O style=tomorrownightbright,linenos=1'
alias jcat="jq '.'"

# ssh
alias psh='ssh -M -S ~/.ssh/ssh-proxy -fNT -D 3222'
alias pshexit='ssh -S ~/.ssh/ssh-proxy -O exit'

# mosh
alias cmosh='LC_ALL="C.UTF-8" mosh'

# curl
alias cfcurl='curl --proxy socks5h://localhost:3211'
alias tpcurl='curl --proxy socks5h://localhost:3215'
alias sscurl='curl --proxy socks5h://localhost:3222'

alias cssh='ssh -o "ProxyCommand=netcat -X 5 -x localhost:3211 %h %p"'
alias tpsh='ssh -o "ProxyCommand=netcat -X 5 -x localhost:3215 %h %p"'
alias pssh='ssh -o "ProxyCommand=netcat -X 5 -x localhost:3222 %h %p"'

# ANSI
alias remove-ansi="sed -r 's/\x1b\[[0-9;]*m//g'"

# run
alias run="action --evaluate"
