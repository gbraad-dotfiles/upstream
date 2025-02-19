#!/bin/zsh

_cockpitinstall() {
  sudo podman container runlabel INSTALL quay.io/cockpit/ws
  sudo systemctl enable --now cockpit.service
}
alias cockpit-install="_cockpitinstall"

