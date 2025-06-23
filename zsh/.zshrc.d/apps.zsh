#!/usr/bin/zsh

CONFIG="${HOME}/.config/dotfiles/applications"
alias appsini="git config -f ${CONFIG}"

_appsdefpath=$(appsini --get "applications.definitions" || echo "${HOME}/.dotapps")
eval _appsdefpath=$(echo ${_appsdefpath})
_appsinstallpath=$(appsini --get "applications.path" || echo "${HOME}/Applications")
eval APPSHOME=$(echo ${_appsinstallpath})
mkdir -p $APPSHOME
export LOCALBIN=${HOME}/.local/bin

_appsdefexists() {
    if [ -d "${_appsdefpath}" ]; then
        return 0  # File exists, return true (0)
    else
        return 1  # File does not exist, return false (1)
    fi
}

_appsdefclone() {
  local repo=$(appsini --get "applications.repository")
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

get_os_id() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    fi
}

_extract_apps_section_script() {
    # $1: action (e.g., run, user-run, dnf-run), $2: file
    awk -v action="$1" '
    /^## / {
        split($0, arr, " ")
        in_section = 0
        for (i = 2; i <= length(arr); i++) {
            if (arr[i] == action) {
                in_section = 1
                next
            }
        }
    }
    in_section && /^```/ { if (++fence==1) next; else {in_section=0; exit} }
    in_section && fence==1 { print }
    ' "$2"
}

_extract_apps_section_markdown() {
    # $1: section name, $2: file
    awk -v section="## $1" '
    $0 == section {in_section=1; next}
    /^## / && in_section {exit}
    in_section {print}
    ' "$2"
}

_select_app_md() {
    local appspath="${_appsdefpath:-$HOME/.dotapps}"
    local lines app key selected relpath desc file

    lines=()
    while IFS= read -r file; do
        relpath="${file#$appspath/}"
        relpath="${relpath%.md}"
        desc=$(grep -m1 '^# ' "$file" | sed 's/^# //')
            lines+=("$(printf "%-30s %s" "$relpath" "$desc")")
    done < <(find -L "$appspath" -type f -name '*.md' ! -name 'README.md' | sort)

    app=$(printf "%s\n" "${lines[@]}" | \
      fzf --prompt="Select app: " \
          --header=$'Enter: select\tCtrl+R: run\tCtrl+I: install\tCtrl+N: info' \
          --bind "ctrl-r:accept" \
          --expect=enter,ctrl-r,ctrl-i,ctrl-n )

    local -a app_lines
    app_lines=("${(@f)app}")
    key="${app_lines[1]}"
    selected="${app_lines[2]}"

    [[ -z "$selected" ]] && return 1
    local path="${selected%% *}"
    case "$key" in
      ctrl-r) echo "$path run" ;;
      ctrl-i) echo "$path install" ;;
      ctrl-n) echo "$path info" ;;
      *)      echo "$path" ;;
    esac
}

_select_app_section() {
    local file="$1"
    local section
    section=$(awk '/^## / {sub(/^## /,""); print}' "$file" | fzf --prompt="Select action: ")
    echo "$section"
}

_apps_fuzzy_pick() {
    # Picks app (if not given) and section (always), returns both as $app $section
    local input="$1"
    local desc_file section action app

    if [[ -z "$input" ]]; then
        input=$(_select_app_md)
        [[ -z "$input" ]] && return 1
    fi

    if [[ "$input" == *" "* ]]; then
        app="${input%% *}"
        action="${input#* }"
    else
        app="$input"
        action=""
    fi

    desc_file="${_appsdefpath}/${app}.md"
    if [[ -n "$action" ]]; then
        section="$action"
    else
        section=$(_select_app_section "$desc_file")
        [[ -z "$section" ]] && return 1
    fi

    echo "$app" "$section"
}

apps() {
    if ! _appsdefexists; then
        _appsdefclone
    fi

    local desc_file
    # If $1 is given, check for its existence right away
    if [[ -n "$1" ]]; then
        desc_file="${_appsdefpath}/${1}.md"
        if [[ ! -f "$desc_file" ]]; then
            echo "No description file for '${1}' found in ${_appsdefpath}"
            return 2
        fi
    fi

    # Fuzzy app and section picker if no arguments
    if [[ -z "$1" || ( -n "$1" && -z "$2" ) ]]; then
        local pick app action
        pick=($(_apps_fuzzy_pick "$1"))
        [[ ${#pick} -eq 0 ]] && return 1
        app="${pick[1]}"
        action="${pick[2]}"
        apps "$app" "$action"
        return
    fi

    background=0
    args=()

    # Loop through all arguments
    for arg in "$@"; do
      if [[ "$arg" == "-bg" || "$arg" == "--background" ]]; then
        background=1
      else
        args+=("$arg")
      fi
    done

    local app="${args[1]}"
    local action="${args[2]}"
    local force_pkg="${args[3]}"

    [[ -z "$app" || -z "$action" ]] && { echo "Usage: apps [appname] [install|remove|run|info] [optional:pkg]"; return 1; }

    if [[ "$action" == "info" ]]; then
        local info_block
        info_block="$(_extract_apps_section_markdown "info" "$desc_file")"
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
    fi

    local pkg=""
    local script=""
    local used_block=""
    local osid=""

    if [[ -n "$force_pkg" ]]; then
        pkg="$force_pkg"
        script="$(_extract_apps_section_script "${pkg}-${action}" "$desc_file")"
        [[ -n "$script" ]] && used_block="${pkg}-${action}"
        if [[ -z "$script" ]]; then
            echo "No block for ${pkg}-${action} in $desc_file"
            return 4
        fi
    else
        osid="$(get_os_id)"
        if [[ -n "$osid" ]]; then
            script="$(_extract_apps_section_script "${osid}-${action}" "$desc_file")"
            [[ -n "$script" ]] && used_block="${osid}-${action}"
        fi
        if [[ -z "$script" ]]; then
            pkg="$(detect_pkg)"
            if [[ -n "$pkg" ]]; then
                script="$(_extract_apps_section_script "${pkg}-${action}" "$desc_file")"
                [[ -n "$script" ]] && used_block="${pkg}-${action}"
            fi
        fi
        [[ -z "$script" ]] && script="$(_extract_apps_section_script "${action}" "$desc_file")"
        [[ -z "$used_block" && -n "$script" ]] && used_block="${action}"
        [[ -z "$script" ]] && { echo "No block for ${osid}-${action}, ${pkg}-${action} or ${action} in $desc_file"; return 4; }
    fi

    # shared section for variables
    for shared_section in shared vars; do
      shared_script="$(_extract_apps_section_script "${shared_section}" "$desc_file")"
      if [[ -n "$shared_script" ]]; then
        eval "$shared_script"
      fi
    done

    #[[ -n "$used_block" ]] && echo "Executing ${action} for ${app} using section: ${used_block}" >&2
    if (( background )); then
      eval "$script" &
      bg_pid=$!
      echo "Started in background (PID $bg_pid)"
      return 0
    else
      output=$(eval "$script")
      exitcode=$?
      echo "$output"
      return $exitcode
    fi 
}

if [[ $(appsini --get "applications.aliases") == true ]]; then
    alias a="apps"
fi

function apps-launcher-widget() {
  zle -I
  apps
  print 
  zle reset-prompt 
}
zle -N apps-launcher-widget
bindkey '^E' apps-launcher-widget
