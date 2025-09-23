#!/bin/zsh

export ACTIONFILE_SHELL=zsh
APPSREPO=$(dotini apps --get "apps.definitions" || echo "${HOME}/.dotapps")
eval APPSREPO=$(echo ${APPSREPO})
APPSHOME=$(dotini apps --get "apps.path" || echo "${HOME}/Applications")
eval APPSHOME=$(echo ${APPSHOME})
APPSCONFIG=$(dotini apps --get "apps.configpath" || echo "${HOME}/.config/dotapps")
eval APPSCONFIG=$(echo ${APPSCONFIG})
mkdir -p $APPSHOME
export LOCALBIN=${HOME}/.local/bin

appini() {
  local appname="$1"
  if [ -z ${appname} ]; then
    echo "No application specified"
    return 1
  fi

  shift

  appconfig="${APPSCONFIG}/${appname}.ini"     
  if [ ! -f "${appconfig}" ]; then
    local result
    result=$(actions_extract_config_block ${APPSREPO}/${appname}.md)
    mkdir -p ${APPSCONFIG}
    if [[ -z ${result} ]]; then
      echo "No application config available"
      return 1
    else
      echo ${result} > ${appconfig}
      echo "Created local configuration for ${appname}"
    fi
  fi
  if [ ! -f "${appconfig}" ]; then
    echo "No local configuration available"
  else
    if echo "$@" | grep -q -- '--edit'; then
      git config -f ${appconfig} --edit
      return 0
    else
      git config -f ${appconfig} $@
    fi
  fi
}


apps_repo_exists() {
  [ -d "${APPSREPO}" ] 
}

apps_repo_clone() {
  local repo=$(dotini apps --get "apps.repository")
  git clone ${repo} ${APPSREPO} --depth 2
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

apps_extract_markdown() {
  # $1: section name, $2: file
  awk -v section="### $1" '
    $0 == section {in_section=1; next}
    (in_section && ($0 ~ /^## / || $0 ~ /^### / || $0 ~ /^---$/)) {exit}
    in_section {print}
    ' "$2"
}

apps_info() {
  local info_block app appfile
  app=$1
  appfile=$2

  info_block="$(apps_extract_markdown "info" "$appfile")"
  if [[ -n "$info_block" ]]; then
    if command -v glow &>/dev/null; then
      echo "$info_block" | glow -
    else
      echo "$info_block"
    fi
  else
    echo "No info section found for $app"
  fi
  return
}

apps_detect_pkg() {
    local forcepkg=$(dotini apps --get "apps.packager")

    if [[ -n "$forcepkg" ]]; then
        echo "$forcepkg"
    elif command -v apt &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v flatpak &>/dev/null; then
        echo "flatpak"
    else
        echo ""
    fi
}

apps_get_osid() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    fi
}

app() {

  if ! apps_repo_exists; then
    apps_repo_clone
  fi

  local APPNAME=$1
  local APPFILE="${APPSREPO}/${APPNAME}.md"
  local list_mode=0
  local edit_mode=0
  local info_mode=0
  local list_actions=0

  local i=1
  while (( i <= $# )); do
    if [[ "${@[i]}" == "--list-apps" ]]; then
      list_mode=1
    elif [[ "${@[i]}" == "--list-actions" ]]; then
      list_actions=1
    elif [[ "${@[i]}" == "--edit" ]]; then
      edit_mode=1
    elif [[ "${@[i]}" == "info" ]]; then
      info_mode=1
    elif [[ "${@[i]}" == "alias" ]]; then
      shift 1
    fi
    ((i++))
  done

  if (( list_actions )); then
    action ${APPFILE} --list-actions | grep -vE '^(info|run|alias|vars|default|shared)$'
    return 0
  fi; 

  if (( edit_mode )); then
    vi ${APPSREPO}/${APPNAME}.md
    return 0
  fi

  if (( list_mode )); then
    apps_list_names_and_descs ${APPSREPO}
    return 0
  fi

  if [[ -n "${APPNAME}" ]]; then
    local common_args=(--arg APPNAME="${APPNAME}" --arg CONFIGPATH="${APPSCONFIG}")

    # Check if application actually defined
    if [[ ! -f "${APPFILE}" ]]; then
      echo "No application Actionfile for '${APPNAME}' found in ${APPSREPO}"
      return 2
    fi

    if (( info_mode )); then
      apps_info ${APPNAME} ${APPFILE}
      return 0
    fi

    shift 1

    local other_args=()
    local override_args=()
    # Loop through all arguments and extract --arg NAME=VALUE
    local skip_next=0 arg nextarg kv
    for ((i=1; i<=$#; i++)); do
      if [[ ${skip_next} -eq 1 ]]; then
        skip_next=0
        continue
      fi
      arg="${@[i]}"
      if [[ "$arg" == "--arg" ]]; then
        # support both '--arg NAME=VAL' and '--arg=NAME=VAL'
        nextarg="${@[i+1]}"
        if [[ "$nextarg" =~ "=" ]]; then
          override_args+=("--arg=$nextarg")
          skip_next=1
        fi
      elif [[ "$arg" == --arg=* ]]; then
        override_args+=("--arg=${arg#--arg=}")
      elif [[ "$arg" == "-bg" || "$arg" == "--background" ]]; then
        override_args+="--background"
      elif [[ "$arg" == "-i" || "$arg" == "--interactive" ]]; then
        override_args+="--evaluate"
      else
        other_args+=("$arg")
      fi
    done

    # Parse remaining arguments as action and context
    local action=${other_args[1]}
    local context=${other_args[2]}
    local selected_action=""

    # Match section according to inferred context
    if [[ -z "$context" ]]; then
      local sections=$(action ${APPFILE} --list-sections)

      # based on packager
      local pkgid="$(apps_detect_pkg)"
      if echo "$sections" | grep -Fxq "${pkgid}-${action}"; then
        selected_action="${pkgid}-${action}"
      fi
      # based on OS (only if not already selected)
      if [ -z "$selected_action" ]; then
        local osid="$(apps_get_osid)"
        if echo "$sections" | grep -Fxq "${osid}-${action}"; then
          selected_action="${osid}-${action}"
        fi
      fi

      # Direct action takes precedence
      if echo "$sections" | grep -Fxq "${action}"; then
        selected_action="${action}"
      fi
    else
      selected_action="${context}-${action}"
    fi

    # Perform execution using 'selected action'
    action ${APPFILE} ${selected_action} ${common_args[@]} ${override_args[@]}

  else

    echo "No application Actionfile specified"

  fi
}
