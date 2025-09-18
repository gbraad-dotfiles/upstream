#!/bin/zsh

alias login-ghcr='podman login ghcr.io -u USERNAME -p $(secrets get ghcr_pat)'
