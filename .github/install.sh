#!/bin/sh

# clean workspace folder
#rm -rf /workspaces/upstream
#ln -s ~/.dotfiles /workspaces/upstream
#
#rm -rf /workspaces/dotfiles
#ln -s ~/.dotfiles /workspaces/dotfiles
#
#rm -rf /workspaces/dotfiles-downstream
#ln -s ~/.dotfiles /workspaces/dotfiles-downstream

# Create user session
sudo loginctl enable-linger gbraad
sudo machinectl shell gbraad@ /usr/bin/echo "User session created"

exit 0
