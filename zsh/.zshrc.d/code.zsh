#!/bin/zsh

CONFIG="${HOME}/.code"
alias codeini="git config -f $CONFIG"

_codepath=$(codeini --get code.path || echo "${HOME}/.local/bin")
eval _codepath=$(echo ${_codepath})

_codeexists() {
    if [ -f "${_codepath}/code" ]; then
        return 0  # File exists, return true (0)
    else
        return 1  # File does not exist, return false (1)
    fi
}

_installcode() {
    # does not handle architecture yet
    arch=$(uname -m)
    case "$arch" in
      x86_64)
        download_target="x64"
        ;;
      i386 | i686)
        download_target="x86"
        ;;
      armv7l)
        download_target="arm32"
        ;;
      aarch64)
        download_target="arm64"
        ;;
      *)
        echo "Unsupported architecture: $arch"
        return 1
        ;;
    esac

    echo "Installing code-cli for: ${download_target}"
    tempfile=$(mktemp)
    curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=cli-alpine-${download_target}" -o ${tempfile}
    tar -zxvf ${tempfile} -C ${_codepath} > /dev/null 2>&1
    rm -f ${tempfile}
}

_startcodetunnel() {
    if ! _codeexists; then
        _installcode
    fi

    if [ -z "${HOSTNAME}" ]; then
        echo "HOSTNAME not set"
	return 1
    fi

    screen ${_codepath}/code tunnel --accept-server-license-terms --name ${HOSTNAME}
}

_startcodeserveweb() {
    if ! _codeexists; then
        _installcode
    fi
    local host=$(codeini --get code.host || echo "0.0.0.0")
    local port=$(codeini --get code.port || echo "8000")

    screen ${_codepath}/code serve-web --without-connection-token --host ${host} --port ${port}
}

alias install-code="_installcode"
alias start-code-tunnel="_startcodetunnel"
alias start-code-serveweb="_startcodeserveweb"

_installcodeifmissing() {
    if ! _codeexists; then
        _installcode
    fi
}

if [[ $(codeini --get "code.autoinstall") == true ]]; then
  _installcodeifmissing
fi
