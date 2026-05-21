# compdef app apps
_apps() {
  local -a appnames
  local appspath="${_appsdefpath:-$HOME/.dotapps}"

  if (( CURRENT == 2 )); then
    appnames=(${(u)${(f)"$(find $appspath -maxdepth 1 -type f -name '*.md' -printf '%P\n' 2>/dev/null | sed -E 's/\.md$//' | grep -v '^README$')"}})
    compadd -a appnames
    return
  fi

  local appfile="${appspath}/${words[2]}.md"
  [[ ! -f "$appfile" ]] && return

  if (( CURRENT == 3 )); then
    local -a actions
    actions=(${(f)"$(app ${words[2]} --list-actions 2>/dev/null)"})
    compadd -Q -a actions
    return
  fi

  _normal
}

#compdef devbox
_devbox() {
  local -a prefixes commands
  local images_output

  images_output=(${(f)"$(dotini devbox --list | grep '^images\.')"})
  prefixes=(${images_output//images./})
  prefixes=(${prefixes//=*/})

  commands=(
    create start stop kill rm remove enter export
    sysctl systemctl systemd ps status screen apps dot dotfiles
    root su user sh shell exec playbook usercmd
  )

  if (( CURRENT == 2 )); then
    _describe 'prefix/image' prefixes
    return
  fi

  if (( CURRENT == 3 )); then
    _describe 'command' commands
    return
  fi

  if (( CURRENT == 4 )) && [[ "$words[3]" == "playbook" ]]; then
    _files
    return
  fi

  _normal
}

#compdef devenv dev
_devenv() {
  local -a prefixes commands

  prefixes=("${(@f)$(devenv_prefixes 2>/dev/null)}")

  commands=(
    env run rootenv userenv userrun create sys system
    noinit dumb nosys init start stop kill rm remove exec execute
    root su user sh shell sysctl systemctl systemd ps status screen
    apps dot dotfiles playbook usercmd tsconnect from
  )

  if (( CURRENT == 2 )); then
    _describe 'prefix/image' prefixes
    return
  fi

  if (( CURRENT == 3 )); then
    _describe 'command' commands
    return
  fi

  if (( CURRENT == 4 )) && [[ "$words[3]" == "playbook" ]]; then
    _files
    return
  fi

  _normal
}

#compdef dev3s d3s
_dev3s() {
  local -a prefixes commands

  prefixes=("${(@f)$(devpods_prefixes 2>/dev/null)}")
  # also include running pod names (strip sys suffix)
  local running
  running=(${(f)"$(kubectl get pods --no-headers 2>/dev/null | awk '$1 ~ /sys$/ {sub(/sys$/,"",$1); print $1}')"})
  prefixes=(${(u)prefixes[@]} ${running[@]})

  commands=(
    deploy from undeploy status logs shell exec
    screen apps dot dotfiles playbook tsconnect switch
  )

  if (( CURRENT == 2 )); then
    if [[ "${words[2]}" == "switch" ]]; then
      return
    fi
    _describe 'prefix/pod' prefixes
    # also offer top-level commands
    local top=(switch)
    _describe 'command' top
    return
  fi

  if (( CURRENT == 3 )); then
    _describe 'command' commands
    return
  fi

  if (( CURRENT == 4 )) && [[ "$words[3]" == "from" ]]; then
    _describe 'source image prefix' prefixes
    return
  fi

  if (( CURRENT == 4 )) && [[ "$words[3]" == "playbook" ]]; then
    _files
    return
  fi

  _normal
}

#compdef secrets
_secrets() {
  local -a commands secretfiles
  local _secretspath

  _secretspath=$(dotini secrets --get secrets.path 2>/dev/null)
  [[ -z $_secretspath ]] && _secretspath="${HOME}/.dotsecrets"
  eval _secretspath="$_secretspath"

  commands=(
    up update in install get show set add var file out totp
  )

  if (( CURRENT == 2 )); then
    _describe 'command' commands
    return
  fi

  case "${words[2]}" in
    get|show|var|file|out|totp)
      secretfiles=()
      if [[ -d "$_secretspath/secrets" ]]; then
        secretfiles=(${(f)"$(cd $_secretspath/secrets && find . -type f -not -path '*/\.*' | sed 's|^\./||')"})
      fi
      if (( CURRENT == 3 )); then
        _describe 'secret' secretfiles
        return
      fi
      if (( CURRENT == 4 )) && [[ "${words[2]}" == (file|out) ]]; then
        _files
        return
      fi
      ;;
  esac

  _normal
}

#compdef machine mcn
_machine() {
  local -a prefixes commands

  prefixes=("${(@f)$(machine_prefixes 2>/dev/null)}")

  commands=(
    download system create start stop kill rm remove
    console shell serial switch copy-config cc
    exec dot apps screen user root su
  )

  if (( CURRENT == 2 )); then
    _describe 'prefix' prefixes
    return
  fi

  if (( CURRENT == 3 )); then
    _describe 'command' commands
    return
  fi

  return 0
}

#compdef proxy
_proxy() {
  local -a prefixes
  prefixes=(${(f)"$(dotini proxy --list | grep '^servers\.' | sed 's/^servers\.//;s/=.*//')"})

  if (( CURRENT == 2 )); then
    _describe 'proxy server' prefixes
    return
  fi

  return 0
}

#compdef dotfiles
_dotfiles() {
  local -a commands
  commands=(
    update install resource reset restow
    destow unload switch upstream dot screen
    apps secrets devbox devenv machine proxy
  )

  if (( CURRENT == 2 )); then
    _describe 'command' commands
    return
  fi

  local subcommand="${words[2]}"
  _dotfiles_delegate() {
    (( CURRENT-- ))
    words=("${words[@]:1}")
    "$1"
  }

  case $subcommand in
    apps)    _dotfiles_delegate _apps; return ;;
    devenv)  _dotfiles_delegate _devenv; return ;;
    devbox)  _dotfiles_delegate _devbox; return ;;
    machine) _dotfiles_delegate _machine; return ;;
    proxy)   _dotfiles_delegate _proxy; return ;;
    secrets) _dotfiles_delegate _secrets; return ;;
  esac

  return 0
}

if whence compdef >/dev/null; then
  compdef _apps app apps
  compdef _devbox devbox
  compdef _devenv devenv dev
  compdef _dev3s dev3s d3s
  compdef _machine machine mcn
  compdef _secrets secrets
  compdef _proxy proxy
  compdef _dotfiles dotfiles
fi
