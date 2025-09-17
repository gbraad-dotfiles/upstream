#!/bin/zsh

_app_defpath=$(dotini apps --get "apps.definitions" || echo "${HOME}/.dotapps")
eval _app_defpath=$(echo ${_app_defpath})
_app_installpath=$(dotini apps --get "apps.path" || echo "${HOME}/Applications")
eval APPSHOME=$(echo ${_app_installpath})
mkdir -p $APPSHOME
export LOCALBIN=${HOME}/.local/bin

app() {

  local appspath="${_app_defpath:-$HOME/.dotapps}"
  local appfile="${_app_defpath}/${1}.md"

  if [[ -n "$1" ]]; then

    if [[ ! -f "$appfile" ]]; then
      echo "No application Actionfile for '${1}' found in ${_app_defpath}"
      return 2
    fi

    shift 1

    action $appfile $@
  else
    echo "No application Actionfile specified"
  fi
}
