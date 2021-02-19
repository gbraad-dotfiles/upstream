if [ ! -z ${SYSTEM_INSTALL+x} ]; then

   # essentials
   sudo dnf install -y \
        mc tmux screen links lynx \
        vim vim-nerdtree vim-airline \
        powerline vim-powerline tmux-powerline

   # fonts
   sudo dnf install -y \
        adobe-source-han-mono-fonts \
        adobe-source-code-pro-fonts \
        adobe-source-sans-pro \
        adobe-source-serif-pro-fonts \
        powerline-fonts

   # optiona
   sudo dnf install -y python3-pygments
   pip install pygments-style-tomorrownightbright

   # graphical
   sudo dnf install -y i3

   unset SYSTSEM_INSTALL
fi
