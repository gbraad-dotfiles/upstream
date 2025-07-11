#!/bin/sh
alias tmn='tmux new-session -s'
alias tma='tmux attach-session -t'
alias tmkill='tmux kill-session -t'

#if [ ! -L "${HOME}/.tmux.conf" ]; then
# Always run with forced config
tmux() { command tmux -2 -f ${HOME}/.dotfiles/tmux/.tmux.conf $@ }
#fi
