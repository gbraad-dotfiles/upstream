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
  alias td='apps taildrop run'
  alias ts='apps tailscale'
  alias tss='apps tailscale status'
  alias tsh='tailscale ssh'
  alias tsip='tailscale ip -4'
  alias tsfon='apps tailscale status online'
  alias tsfdir='apps tailscale status direct'
  alias tsfexit='apps tailscale status exitnode'
  alias tskey='secrets var tailscale_authkey'
  alias tsup='sudo tailscale up --auth-key $TAILSCALE_AUTHKEY'
  alias tsconnect='tskey; tsup'
fi

if [[ $(dotini tailscale --get "tailproxy.aliases") == true ]]; then
  # tailproxy helpers
  alias tp='apps tailproxy'
  alias tpkill='apps tailproxy kill'
  alias tps='apps tailproxy status'
  alias tph='tailproxy ssh'
  alias tpip='tailproxy ip -4'
  alias tpfon='apps tailproxy status online'
  alias tpfdir='apps tailproxy status direct'
  alias tpfexit='apps tailproxy status exitnode'
  alias tpexit='apps tailproxy exitnode select'
  alias tpmull='apps tailproxy exitmull select'
  alias tptp='tailproxy; proxy tailproxy-resolve'
  alias tpkey='secrets var tailscale_authkey'
  alias tpup='tailproxy up --auth-key $TAILSCALE_AUTHKEY'
  alias tpconnect='tpkey; tpup'

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

