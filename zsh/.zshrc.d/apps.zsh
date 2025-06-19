#!/usr/bin/zsh

CONFIG="${HOME}/.config/dotfiles/applications"
alias appsini="git config -f ${CONFIG}"

_appsdefpath=$(appsini --get applications.definitions || echo "${HOME}/.dotapps")
eval _appsdefpath=$(echo ${_appsdefpath})
_appsinstallpath=$(appsini --get applications.path || echo "${HOME}/Applications")
eval APPSHOME=$(echo ${_appsinstallpath})
mkdir -p $APPSHOME

_appsdefexists() {
    if [ -d "${_appsdefpath}" ]; then
        return 0  # File exists, return true (0)
    else
        return 1  # File does not exist, return false (1)
    fi
}

_appsdefclone() {
  local repo=$(appsini --get applications.repository)
  git clone ${repo} ${_appsdefpath} --depth 2
}

detect_pkg() {
    if [[ -n "$FORCE_PKG" ]]; then
        echo "$FORCE_PKG"
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

extract_section() {
    # $1: section name (e.g., flatpak-run), $2: file
    awk -v section="## $1" '
    $0 == section { in_section=1; next }
    in_section && /^```/ { if (++fence==1) next; else {in_section=0; exit} }
    in_section && fence==1 { print }
    ' "$2"
}

apps() {
  if ! _appsdefexists; then
    _appsdefclone
  fi

    local app="$1"
    local action="$2"
    local force_pkg="$3"
    [[ -z "$app" || -z "$action" ]] && { echo "Usage: apps [appname] [install|remove|run] [optional:pkg]"; return 1; }
    local desc_file="${_appsdefpath}/${app}.md"
    [[ ! -f "$desc_file" ]] && { echo "No description file for '$app' found in $_appsdefpath"; return 2; }
    local pkg=""
    local script=""
    local used_pkg=""

    if [[ -n "$force_pkg" ]]; then
        pkg="$force_pkg"
        script="$(extract_section "${pkg}-${action}" "$desc_file")"
        if [[ -z "$script" ]]; then
            echo "No block for ${pkg}-${action} in $desc_file"
            return 4
        fi
        used_pkg="$pkg"
    else
        pkg="$(detect_pkg)"
        if [[ -n "$pkg" ]]; then
            script="$(extract_section "${pkg}-${action}" "$desc_file")"
            [[ -n "$script" ]] && used_pkg="$pkg"
        fi
        [[ -z "$script" ]] && script="$(extract_section "${action}" "$desc_file")"
        [[ -z "$script" ]] && { echo "No block for ${pkg}-${action} or ${action} in $desc_file"; return 4; }
    fi

    if [[ -n "$used_pkg" ]]; then
        echo "Executing ${action} for ${app} using ${used_pkg}..."
    else
        echo "Executing ${action} for ${app}..."
    fi

    eval "$script"
}
