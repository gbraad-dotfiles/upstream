#!/bin/zsh
CONTAINER_RUNTIME="${1:-podman}"

# pandoc: https://gitlab.com/gbraad/docugen
alias pandoc='${CONTAINER_RUNTIME} run -it --rm -v $PWD:/workspace ghcr.io/gbraad/docugen pandoc'

# LibreOffice (convert: --headless --convert-to odt *.docx)
#alias libreoffice='${CONTAINER_RUNTIME} run --rm -v $PWD:/workspace registry.gitlab.com/gbraad/libreoffice:latest libreoffice'
#alias=libreoffice='${CONTAINER_RUNTIME} run -v $PWD:/workspace registry.gitlab.com/gbraad/libreoffice:latest flatpak run org.libreoffice.LibreOffice'

# others
alias youtube-dl='${CONTAINER_RUNTIME} run --rm -u $(id -u):$(id -g) -v $PWD:/data vimagick/youtube-dl'
alias nginx-pwd='${CONTAINER_RUNTIME} run --name nginx-pwd -p 80:80 -v $PWD:/usr/share/nginx/html:ro -d nginx'

# Steam powered
#alias steamcmd='${CONTAINER_RUNTIME} run -it -v $HOME/Steam:/home/user/Steam registry.gitlab.com/gbraad/steamcmd:latest'
# New image published to github.com/gbraad-gaming/personal-steam-cmd

# hostenter
alias hostenter='${CONTAINER_RUNTIME} run --rm -it --privileged --pid=host gbraad/hostenter /bin/bash'

# fedora coreos
alias fcos='podman run -d --name=fcos --hostname $HOSTNAME-fcos --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun quay.io/fedora/fedora-coreos:stable /sbin/init'
alias fcosroot='${CONTAINER_RUNTIME} exec -it fcos /bin/bash'

# cloudflared / tailscale(d)
alias flaresys='podman run -d --name=flaresys --hostname $HOSTNAME-flaresys --network=host --systemd=always ghcr.io/spotsnel/cloudflared-systemd/fedora:latest'
#alias scalesys='podman run -d --name=scalesys --hostname $HOSTNAME-scalesys --network=host --systemd=always ghcr.io/spotsnel/tailscale-systemd/fedora:latest'
alias scalesys=tailsys

alias login-quay='podman login -u gbraad -p $(secrets get quay)'

# OCI registry client
_install_oras() {
  VERSION="1.2.0"
  local TEMP_DIR=$(mktemp -d)
  curl -fsSL "https://github.com/oras-project/oras/releases/download/v${VERSION}/oras_${VERSION}_linux_amd64.tar.gz" -o ${TEMP_DIR}/oras.tar.gz
  tar -zxf ${TEMP_DIR}/oras.tar.gz -C ${TEMP_DIR}/
  mv ${TEMP_DIR}/oras ~/.local/bin/
  rm -rf ${TEMP_DIR}/
}
alias install-oras=_install_oras
