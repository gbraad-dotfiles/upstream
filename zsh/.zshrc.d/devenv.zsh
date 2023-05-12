#!/bin/zsh
CONTAINER_RUNTIME="${1:-podman}"


# --- Fedora devenv --- https://github.com/gbraad-devenv/fedora
FEDORA_VERSION="38"

# dotfiles
alias defenv='${CONTAINER_RUNTIME} run -it --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun --rm -v $HOME/Projects:/home/${USER}/Projects --entrypoint="" ghcr.io/gbraad-devenv/fedora/dotfiles:${FEDORA_VERSION} /bin/zsh'

# systemd
alias defsys='podman run -d --name=devsys --hostname $HOSTNAME-devsys --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun -v $HOME/Projects:/home/${USER}/Projects ghcr.io/gbraad-devenv/fedora/systemd:${FEDORA_VERSION} '
alias defdock='docker run -d --name=devsys --hostname $HOSTNAME-devsys --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun -v $HOME/Projects:/home/${USER}/Projects --entrypoint="" ghcr.io/gbraad-devenv/fedora/dotfiles:${FEDORA_VERSION}  sleep infinity'
alias defroot='${CONTAINER_RUNTIME} exec -it devsys /bin/zsh'
alias defuser='${CONTAINER_RUNTIME} exec -it devsys su - gbraad'


# --- Debian devenv --- https://github.com/gbraad-devenv/debian/
DEBIAN_VERSION="bullseye"

# dotfiles
alias debenv='${CONTAINER_RUNTIME} run -it --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun --rm -v $HOME/Projects:/home/${USER}/Projects --entrypoint="" ghcr.io/gbraad-devenv/debian/dotfiles:${DEBIAN_VERSION} /bin/zsh'

# systemd
alias debsys='podman run -d --name=debsys --hostname $HOSTNAME-debsys --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun -v $HOME/Projects:/home/${USER}/Projects ghcr.io/gbraad-devenv/debian/systemd:${DEBIAN_VERSION}'
alias debroot='${CONTAINER_RUNTIME} exec -it debsys /bin/zsh'
alias debuser='${CONTAINER_RUNTIME} exec -it debsys su - gbraad'


# --- Alpine devenv --- https://github.com/gbraad-devenv/alpine/
ALPINE_VERSION="3.18"

# dotfiles
alias alpenv='${CONTAINER_RUNTIME} run -it --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun --rm -v $HOME/Projects:/home/${USER}/Projects --entrypoint="" ghcr.io/gbraad-devenv/alpine/dotfiles:${ALPINE_VERSION} /bin/zsh'


# --- CentOS devenv --- https://github.com/gbraad-devenv/centos/
CENTOS_VERSION="stream9"

# dotfiles
alias cenenv='${CONTAINER_RUNTIME} run -it --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun --rm -v $HOME/Projects:/home/${USER}/Projects --entrypoint="" ghcr.io/gbraad-devenv/centos/dotfiles:${CENTOS_VERSION} /bin/zsh'

# systemd
alias censys='podman run -d --name=censys --hostname $HOSTNAME-censys --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun -v $HOME/Projects:/home/${USER}/Projects ghcr.io/gbraad-devenv/centos/systemd:${CENTOS_VERSION}'
alias cenroot='${CONTAINER_RUNTIME} exec -it censys /bin/zsh'
alias cenuser='${CONTAINER_RUNTIME} exec -it censys su - gbraad'


# --- Ubuntu devenv --- https://github.com/gbraad-devenv/ubuntu/
UBUNTU_VERSION="jammy"

# dotfiles
alias ubuenv='${CONTAINER_RUNTIME} run -it --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun --rm -v $HOME/Projects:/home/${USER}/Projects --entrypoint="" ghcr.io/gbraad-devenv/ubuntu/dotfiles:${UBUNTU_VERSION} /bin/zsh'

# systemd
alias ubusys='podman run -d --name=ubusys --hostname $HOSTNAME-ubusys --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun -v $HOME/Projects:/home/${USER}/Projects ghcr.io/gbraad-devenv/ubuntu/systemd:${UBUNTU_VERSION}'
alias uburoot='${CONTAINER_RUNTIME} exec -it ubusys /bin/zsh'
alias ubuuser='${CONTAINER_RUNTIME} exec -it ubusys su - gbraad'


# --- base on host distro
source /etc/os-release

if [ "$ID" = "fedora" ]
then
    alias devenv=defenv
    alias devsys=defsys
    alias devroot=defroot
    alias devuser=defuser
elif [ "$ID" = "debian" ]
then
    alias devenv=debenv
    alias devsys=debsys
    alias devroot=debroot
    alias devuser=debuser
fi
