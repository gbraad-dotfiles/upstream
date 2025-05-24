# User configuration
export PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH:/usr/lib64/qt-3.3/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/sbin:/home/ubuntu/.local/bin:/home/gbraad/bin:/home/gbraad/node_modules/.bin:/data/data/com.termux/files/usr/bin:/data/data/com.termux/files/usr/bin/applets"
# export MANPATH="/usr/local/man:$MANPATH"

# # Preferred editor for local and remote sessions
#if [[ -n $SSH_CONNECTION ]]; then
#  export EDITOR=vim
#else
#  export EDITOR='vim'
#fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

source ${HOME}/.dotfiles/source.sh
