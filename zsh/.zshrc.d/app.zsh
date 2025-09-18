#!/bin/zsh

export ACTIONFILE_SHELL=zsh
_app_defpath=$(dotini apps --get "apps.definitions" || echo "${HOME}/.dotapps")
eval _app_defpath=$(echo ${_app_defpath})
_app_installpath=$(dotini apps --get "apps.path" || echo "${HOME}/Applications")
eval APPSHOME=$(echo ${_app_installpath})
mkdir -p $APPSHOME
export LOCALBIN=${HOME}/.local/bin
APPSREPO="${_app_defpath:-$HOME/.dotapps}"

apps_repo_exists() {
    if [ -d "${APPSREPO}" ]; then
        return 0
    else
        return 1
    fi
}

apps_repo_clone() {
  local repo=$(dotini apps --get "apps.repository")
  git clone ${repo} ${_appsdefpath} --depth 2
}

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

  if ! apps_repo_exists; then
    apps_repo_clone
  fi

  local appspath="${APPSREPO:-$HOME/.dotapps}"
  local APPNAME=$1
  local APPFILE="${APPSREPO}/${APPNAME}.md"
  local list_mode=0

  local i=1
  while (( i <= $# )); do
    if [[ "${@[i]}" == "--list-apps" ]]; then
      list_mode=1
    fi
    ((i++))
  done

  if (( list_mode )); then
    app_list_names_and_descs ${APPSREPO}
    return 0
  fi

  if [[ -n "$1" ]]; then

    if [[ ! -f "${APPFILE}" ]]; then
      echo "No application Actionfile for '${APPNAME}' found in ${APPSREPO}"
      return 2
    fi

    shift 1

    action ${APPFILE} $@ --arg APPNAME=${APPNAME} --subshell

  else
    echo "No application Actionfile specified"
  fi
}
