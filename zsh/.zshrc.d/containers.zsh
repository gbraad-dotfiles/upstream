#!/bin/zsh
CONTAINER_RUNTIME="${1:-podman}"

# others
alias youtube-dl='${CONTAINER_RUNTIME} run --rm -u $(id -u):$(id -g) -v $PWD:/data vimagick/youtube-dl'
alias nginx-pwd='${CONTAINER_RUNTIME} run --name nginx-pwd -p 80:80 -v $PWD:/usr/share/nginx/html:ro -d nginx'

# hostenter
alias hostenter='${CONTAINER_RUNTIME} run --rm -it --privileged --pid=host gbraad/hostenter /bin/bash'

# fedora coreos
alias fcos='podman run -d --name=fcos --hostname $HOSTNAME-fcos --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun quay.io/fedora/fedora-coreos:stable /sbin/init'
alias fcosroot='${CONTAINER_RUNTIME} exec -it fcos /bin/bash'

alias login-quay='podman login -u gbraad -p $(secrets get quay)'
