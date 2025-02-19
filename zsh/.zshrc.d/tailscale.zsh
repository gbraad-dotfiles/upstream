#!/bin/zsh

CONFIG="${HOME}/.config/dotfiles/tailscale"
alias tailscaleini="git config -f $CONFIG"

# general helpers
alias offline_filter='grep -v "offline"'
alias direct_filter='grep "direct"'
alias exitnode_filter='grep "offers exit node"'
alias comment_filter='grep -Ev "^\s*($|#)"'

if [[ $(tailscaleini --get "tailscale.aliases") == true ]]; then
  # tailscale helpers
  alias ts='tailscale'
  alias tss='ts status | comment_filter'
  alias tsh='ts ssh'
  alias tsip='ts ip -4'
  alias tsfon='tss | offline_filter'
  alias tsfdir='tss | direct_filter'
  alias tsfexit='tss | exitnode_filter'
  alias tskey='secrets var tailscale_authkey'
  alias tsup='sudo tailscale up --auth-key $TAILSCALE_AUTHKEY'
  alias tsconnect='tskey; tsup'
fi

if [[ $(tailscaleini --get "tailproxy.aliases") == true ]]; then
  # tailproxy helpers
  alias tp='tailproxy'
  alias tpkill='tailproxy-kill'
  alias tps='tp status | comment_filter'
  alias tph='tp ssh'
  alias tpip='tp ip -4'
  alias tpfon='tps | offline_filter'
  alias tpfdir='tps | direct_filter'
  alias tpfexit='tps | exitnode_filter'
  alias tpexit='tailproxy-exit'
  alias tpmull='tailproxy-mull'
  alias tptp='tailproxy; tpexit; proxy tailproxy-resolve'
  alias tpkey='secrets var tailscale_authkey'
  alias tpup='tp up --auth-key $TAILSCALE_AUTHKEY'
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

# install for other platforms
alias install-tailscale="curl -fsSL https://tailscale.com/install.sh | sh"

# tailproxy (user mode instance)
alias tailproxy=". ~/.local/bin/start-tailproxy"

# tailscale (user mode)
alias start-tailscale="screen -d -m tailscaled --tun='userspace-networking' --socket=/var/run/tailscale/tailscaled.sock"

# containers
alias tailpod='podman run -d   --name=tailscaled --env TS_AUTHKEY=$TAILSCALE_AUTHKEY -v /var/lib:/var/lib --network=host --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun tailscale/tailscale'
alias tailwings='podman run -d --name=tailwings  --env TAILSCALE_AUTH_KEY=$TAILSCALE_AUTHKEY --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun ghcr.io/spotsnel/tailscale-tailwings:latest'
alias tailsys='podman run -d   --name=tailsys    --env TAILSCALE_AUTH_KEY=$TAILSCALE_AUTHKEY --network=host --systemd=always --cap-add=NET_ADMIN --cap-add=NET_RAW --device=/dev/net/tun ghcr.io/spotsnel/tailscale-systemd/fedora:latest'

