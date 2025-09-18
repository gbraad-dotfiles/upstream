#!/bin/zsh

# general helpers
alias online_filter='grep -v "offline"'
alias offline_filter='grep "offline"'
alias direct_filter='grep "direct"'
alias exitnode_filter='grep "offers exit node"'
alias comment_filter='grep -Ev "^\s*($|#)"'
alias tagged_filter='grep "tagged-devices"'
alias assigned_filter='grep -v "tagged-devices"'
alias tsnet_filter='grep ".ts.net"'

if [[ $(dotini tailscale --get "tailscale.aliases") == true ]]; then
  # tailscale helpers
  alias td='app taildrop run'
  alias ts='app tailscale'
  alias tss='app tailscale status'
  alias tsh='tailscale ssh'
  alias tsip='tailscale ip -4'
  alias tpexit='app tailscale exitnode select'
  alias tpmull='app tailscale exitmull select'
  alias tsconnect='app tailscale connect'
fi

if [[ $(dotini tailscale --get "tailproxy.aliases") == true ]]; then
  # tailproxy helpers
  alias tp='app tailproxy'
  alias tpkill='app tailproxy kill'
  alias tps='app tailproxy status'
  alias tph='tailproxy ssh'
  alias tpip='tailproxy ip -4'
  alias tpexit='app tailproxy exitnode select'
  alias tpmull='app tailproxy exitmull select'
  alias tptp='app tailproxy up; proxy tailproxy-resolve'
  alias tpconnect='app tailproxy connect'

  # ssh/scp over tailproxy
  PROXYHOST="localhost:3215"
  PROXYCMD="ProxyCommand /usr/bin/nc -x ${PROXYHOST} %h %p"
  alias tpssh='ssh -o "${PROXYCMD}"'
  alias tpscp='scp -o "${PROXYCMD}"'
  alias tpcurl='curl -x socks5h://${PROXYHOST}'
fi

if [[ $(uname) == "Darwin" ]]; then
    alias tailscale='/Applications/Tailscale.app//Contents/MacOS/Tailscale'
fi

# containers
alias tailpod='podman run -d   --name=tailscaled --env TS_AUTHKEY=$TAILSCALE_AUTHKEY -v /var/lib:/var/lib --network=host --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun tailscale/tailscale'
alias tailwings='podman run -d --name=tailwings  --env TAILSCALE_AUTH_KEY=$TAILSCALE_AUTHKEY --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun ghcr.io/spotsnel/tailscale-tailwings:latest'
alias tailsys='podman run -d   --name=tailsys    --env TAILSCALE_AUTH_KEY=$TAILSCALE_AUTHKEY --network=host --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun ghcr.io/spotsnel/tailscale-systemd/fedora:latest'

