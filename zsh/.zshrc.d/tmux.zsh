#!/bin/sh
alias tmn='tmux new-session -s'
alias tma='tmux attach-session -t'
alias tmkill='tmux kill-session -t'

if [ ! -L "${HOME}/.tmux.conf" ]; then
  tmux() { command tmux -2 -f ${HOME}/.dotfiles/tmux/.tmuxdot.conf $@ }
fi
