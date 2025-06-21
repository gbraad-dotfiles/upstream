#!/bin/zsh

# Allow code to run unnagged in WSL
export DONT_PROMPT_WSL_INSTALL=1

CONFIG="${HOME}/.config/dotfiles/code"
alias codeini="git config -f $CONFIG"

_startcodetunnel() {
    if [ -z "${HOSTNAME}" ]; then
        echo "HOSTNAME not set"
	return 1
    fi

    screen ${_codepath}/code tunnel --accept-server-license-terms --name ${HOSTNAME}
}

_startcodeserveweb() {
    local host=$(codeini --get code.host || echo "0.0.0.0")
    local port=$(codeini --get code.port || echo "8000")

    screen ${_codepath}/code serve-web --without-connection-token --host ${host} --port ${port}
}

if [[ $(codeini --get "code.autoinstall") == true ]]; then
  apps code install cli
fi
