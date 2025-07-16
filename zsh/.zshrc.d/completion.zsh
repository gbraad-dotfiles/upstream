# compdef apps 
_apps() {
  local -a appnames actions sections all_options
  local appspath="${_appsdefpath:-$HOME/.dotapps}"

  if (( CURRENT == 2 )); then
    appnames=(${(u)${(f)"$(find $appspath -type f -name '*.md' -printf '%P\n' 2>/dev/null | sed -E 's/\.md$//' | grep -v '^README$')"}})
    _describe 'application' appnames
    return
  fi

  local appfile="${appspath}/${words[2]}.md"
  [[ ! -f "$appfile" ]] && return

  local -a md_headings
  md_headings=("${(@f)$(grep -E '^## ' "$appfile" | sed 's/^## //')}")

  local heading word action section
  local -A section_actions
  local -A seen_section seen_action

  for heading in "${md_headings[@]}"; do
    for word in ${(z)heading}; do
      if [[ "$word" == *-* ]]; then
        section="${word##*-}"
        action="${word[1,-${#section}-2]}"
        section_actions[$section]+="$action "
        seen_section[$section]=1
      else
        seen_action[$word]=1
      fi
    done
  done

  actions=(${(k)seen_action})
  sections=(${(k)seen_section})

  if (( CURRENT == 3 )); then
    all_options=(${actions[@]} ${sections[@]})
    _describe 'action or section' all_options
    return
  fi

  if (( CURRENT == 4 )); then
    local sec="${words[3]}"
    if [[ -n ${section_actions[$sec]} ]]; then
      local sect_acts
      sect_acts=(${(u)${(z)section_actions[$sec]}})
      _describe 'section action' sect_acts
      return
    fi
  fi
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

#compdef devenv
_devenv() {
  local -a prefixes commands
  local images_output

  images_output=(${(f)"$(dotini devenv --list | grep '^images\.')"})
  prefixes=(${images_output//images./})
  prefixes=(${prefixes//=*/})

  commands=(
    env run rootenv userenv userrun create sys system
    noinit dumb nosys init start stop kill rm remove exec execute
    root su user sh shell sysctl systemctl systemd ps status screen
    apps dot dotfiles playbook usercmd
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

  # If completing the first argument
  if (( CURRENT == 2 )); then
    _describe 'command' commands
    return
  fi

  # For commands that take a secret name as second argument
  case "${words[2]}" in
    get|show|var|file|out|totp)
      secretfiles=()
      # List secrets, strip ./ prefix if any, ignore hidden
      if [[ -d "$_secretspath/secrets" ]]; then
        secretfiles=(${(f)"$(cd $_secretspath/secrets && find . -type f -not -path '*/\.*' | sed 's|^\./||')"})
      fi
      if (( CURRENT == 3 )); then
        _describe 'secret' secretfiles
        return
      fi
      # For file/out, third arg is output file, use _files for path
      if (( CURRENT == 4 )) && [[ "${words[2]}" == (file|out) ]]; then
        _files
        return
      fi
      ;;
  esac

  _normal
}

#compdef machine
_machine() {
  local -a prefixes commands
  local disks_output

  disks_output=(${(f)"$(dotini machine --list | grep '^disks\.')"})
  prefixes=(${disks_output//disks./})
  prefixes=(${prefixes//=*/})

  commands=(
    download system create start stop kill rm remove
    console shell serial switch copy-config cc
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
  compdef _apps apps
  compdef _devbox devbox
  compdef _devenv devenv
  compdef _machine machine
  compdef _secrets secrets
  compdef _proxy proxy
  compdef _dotfiles dotfiles
fi
