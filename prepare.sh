#!/bin/sh

curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install packer
packer plugin install github.com/hashicorp/qemu
packer plugin install github.com/jetbrains-infra/packer-builder-qemu-import
