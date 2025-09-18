#!/bin/zsh

export ACTIONFILE_SHELL=zsh
APPSREPO=$(dotini apps --get "apps.definitions" || echo "${HOME}/.dotapps")
eval APPSREPO=$(echo ${APPSREPO})
APPSHOME=$(dotini apps --get "apps.path" || echo "${HOME}/Applications")
eval APPSHOME=$(echo ${APPSHOME})
mkdir -p $APPSHOME
export LOCALBIN=${HOME}/.local/bin

apps_repo_exists() {
  [ -d "${APPSREPO}" ] 
}

apps_repo_clone() {
  local repo=$(dotini apps --get "apps.repository")
  git clone ${repo} ${_appsdefpath} --depth 2
}

apps_list_names_and_descs() {
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
    apps_list_names_and_descs ${APPSREPO}
    return 0
  fi

  if [[ -n "$1" ]]; then

    # Check if application actually defined
    if [[ ! -f "${APPFILE}" ]]; then
      echo "No application Actionfile for '${APPNAME}' found in ${APPSREPO}"
      return 2
    fi

    shift 1

    # Perform execution as action
    action ${APPFILE} $@ --arg APPNAME=${APPNAME}

  else

    echo "No application Actionfile specified"

  fi
}
