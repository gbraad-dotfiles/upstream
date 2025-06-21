#!/bin/zsh
if [ ! -z ${SYSTEM_INSTALL+x} ]; then
    apps fedora/system install
fi
