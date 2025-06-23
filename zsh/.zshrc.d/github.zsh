#!/bin/zsh

alias login-ghcr='podman login ghcr.io -u USERNAME -p $(secrets get ghcr_pat)'
alias install-ghcli="apps ghcli install"
alias install-ghcli-secret="apps ghcli secret"
