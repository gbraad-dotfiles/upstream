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
    # $1: section name (e.g., flatpak-run), $2: file
    awk -v section="## $1" '
    $0 == section { in_section=1; next }
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
    local relfiles app
    # Find all .md files except README.md, return relative paths without .md
    relfiles=("${(@f)$(find -L "${_appsdefpath}" -type f -name '*.md' ! -name 'README.md' | sed "s|^${_appsdefpath}/||" | sed 's/\.md$//' | sort)}")
    app=$(printf "%s\n" "${relfiles[@]}" | fzf --prompt="Select app: ")
    [[ -z "$app" ]] && return 1
    echo "$app"
}

_select_app_section() {
    local file="$1"
    local section
    section=$(awk '/^## / {sub(/^## /,""); print}' "$file" | fzf --prompt="Select action: ")
    echo "$section"
}

_apps_fuzzy_pick() {
    # Picks app (if not given) and section (always), returns both as $app $section
    local app="$1"
    local desc_file section

    if [[ -z "$app" ]]; then
        app=$(_select_app_md)
        [[ -z "$app" ]] && return 1
    fi

    desc_file="${_appsdefpath}/${app}.md"
    [[ ! -f "$desc_file" ]] && { echo "No description file for '$app' found in $_appsdefpath"; return 2; }

    section=$(_select_app_section "$desc_file")
    [[ -z "$section" ]] && return 1

    echo "$app" "$section"
}

apps() {
    if ! _appsdefexists; then
        _appsdefclone
    fi

    # Fuzzy app and section picker if no arguments
    if [[ -z "$1" || ( -n "$1" && -z "$2" ) ]]; then
        local pick app section
        pick=($(_apps_fuzzy_pick "$1"))
        [[ ${#pick} -eq 0 ]] && return 1
        app="${pick[1]}"
        section="${pick[2]}"
        if [[ "$section" == "info" ]]; then
            apps "$app" "info"
        else
            apps "$app" "$section"
        fi
        return
    fi

    local app="$1"
    local action="$2"
    local force_pkg="$3"
    [[ -z "$app" || -z "$action" ]] && { echo "Usage: apps [filename] [install|remove|run|info] [optional:pkg]"; return 1; }
    local desc_file="${_appsdefpath}/${app}.md"
    [[ ! -f "$desc_file" ]] && { echo "No description file for '$app' found in $_appsdefpath"; return 2; }

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

    #[[ -n "$used_block" ]] && echo "Executing ${action} for ${app} using section: ${used_block}" >&2
    output=$(eval "$script")
    exitcode=$?
    echo "$output"
    return $exitcode
    
}

if [[ $(appsini --get "applications.aliases") == true ]]; then
    alias a="apps"
fi
