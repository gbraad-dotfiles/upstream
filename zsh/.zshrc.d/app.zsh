#!/bin/zsh

export ACTIONFILE_SHELL=zsh
_app_defpath=$(dotini apps --get "apps.definitions" || echo "${HOME}/.dotapps")
eval _app_defpath=$(echo ${_app_defpath})
_app_installpath=$(dotini apps --get "apps.path" || echo "${HOME}/Applications")
eval APPSHOME=$(echo ${_app_installpath})
mkdir -p $APPSHOME
export LOCALBIN=${HOME}/.local/bin

app_list_names_and_descs() {
    local appspath="$1"
    find -L "$appspath" -type f -name '*.md' ! -name 'README.md' | sort | while IFS= read -r file; do
        relpath="${file#$appspath/}"
        relpath="${relpath%.md}"
        desc=$(grep -m1 '^# ' "$file" | sed 's/^# //')
        printf "%s\t%s\n" "$relpath" "$desc"
    done
}

app() {

  local appspath="${_app_defpath:-$HOME/.dotapps}"
  local appfile="${_app_defpath}/${1}.md"
  local list_mode=0

  local i=1
  while (( i <= $# )); do
    if [[ "${@[i]}" == "--list-apps" ]]; then
      list_mode=1
    fi
    ((i++))
  done

  if (( list_mode )); then
    app_list_names_and_descs ${_app_defpath}
    return 0
  fi

  if [[ -n "$1" ]]; then

    if [[ ! -f "$appfile" ]]; then
      echo "No application Actionfile for '${1}' found in ${_app_defpath}"
      return 2
    fi

    shift 1

    action $appfile $@ --subshell
  else
    echo "No application Actionfile specified"
  fi
}
