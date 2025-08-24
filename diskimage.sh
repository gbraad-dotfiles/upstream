#!/bin/sh
#
TAG=$(date +'%y%m%d')

podman build -t ghcr.io/gbraad-dotfiles/debian-disk:latest -f Containerfile-disk .

podman tag ghcr.io/gbraad-dotfiles/debian-disk:latest ghcr.io/gbraad-dotfiles/debian-disk:${TAG}

# podman login ghcr.io -u ${{ github.actor }} -p ${{ secrets.GITHUB_TOKEN }}

podman push ghcr.io/gbraad-dotfiles/debian-disk:latest
podman push ghcr.io/gbraad-dotfiles/debian-disk:${TAG}
