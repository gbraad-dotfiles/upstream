#!/usr/bin/zsh

_appsdefpath=$(dotini apps --get "apps.definitions" || echo "${HOME}/.dotapps")
eval _appsdefpath=$(echo ${_appsdefpath})
_appsinstallpath=$(dotini apps --get "apps.path" || echo "${HOME}/Applications")
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
  local repo=$(dotini apps --get "apps.repository")
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
    awk -v action="$1" '
    /^### / {
        split($0, arr, " ")
        in_section = 0
        for (i = 2; i <= NF; i++) {
            if (arr[i] == action) {
                in_section = 1
                next
            }
        }
    }
    in_section && /^```/ { 
        if (++fence==1) {
            # Portable extraction of the label
            split($0, parts, /[ ]+/)
            if (length(parts) > 1) {
                label = parts[2]
                if (label != "") {
                    print "#__APPS_SH_MODE__=" label
                }
            }
            next
        } else {
            in_section=0; 
            exit
        }
    }
    in_section && fence==1 { print }
    ' "$2"
}

_extract_apps_section_markdown() {
    # $1: section name, $2: file
    awk -v section="## $1" '
    $0 == section {in_section=1; next}
    /^### / && in_section {exit}
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
          --header=$'Enter: select\tCtrl+R: run\tCtrl+B: run bg\tCtrl+I: install\tCtrl+N: info\tF5: export .desktop\tF6: export .service' \
          --bind "ctrl-r:accept" \
          --expect=enter,ctrl-r,ctrl-i,ctrl-n,ctrl-b,f5,f6 )

    local -a app_lines appname apptitle
    app_lines=("${(@f)app}")
    key="${app_lines[1]}"
    selected="${app_lines[2]}"

    [[ -z "$selected" ]] && return 1
    fields=(${(z)selected})
    appname="${fields[1]}"
    apptitle="${fields[2, -1]}"

    case "$key" in
      ctrl-r) echo "$appname run --interactive" ;;
      ctrl-b) echo "$appname run --background" ;;
      ctrl-i) echo "$appname install" ;;
      ctrl-n) echo "$appname info" ;;
      # return 130 to match Ctrl-C behaviour
      f5)     apps-desktop-install "$appname" "$apptitle"; return 130 ;;
      f6)     apps-service-install "$appname" "$apptitle"; return 130 ;;
      *)      echo "$appname" ;;
    esac
}

_apps_action_list() {
  local desc_file="$1"
  awk '
    /^### / {
      sub(/^## /,"");
      for (i=1; i<=NF; i++) {
        word = $i
        dash = index(word, "-")
        if (dash == 0) {
          print word
        } else {
          action = substr(word, dash+1)
          context = substr(word, 1, dash-1)
          print action " " context
        }
      }
    }
  ' "$desc_file" | sort -u
}

_select_app_section() {
    local file="$1"
    local section
    section=$(_apps_action_list "$file" | fzf --prompt="Select action: ")
    echo "$section"
}

_apps_fuzzy_pick() {
    # Picks app (if not given) and section (always), returns both as $app $section
    local input="$1"
    local desc_file section action app

    if [[ -z "$input" ]]; then
        input=$(_select_app_md)
        local input_status=$?
        [[ -z "$input" || $input_status -ne 0 ]] && return 130
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

    echo "$app" "${section}"
}

_find_default_section() {
    # $1: file
    awk '/^### default[ ]+/ {print $3; exit}' "$1"
}

apps() {
    if ! _appsdefexists; then
        _appsdefclone
    fi

    local desc_file
    # If $1 is given, check for its existence right away
    if [[ -n "$1" ]]; then

        # allow the use of a filename being passed
        if [[ "$1" = "." && -f "README.md" ]]; then
          desc_file="./README.md"
        elif [[ -f "$1" || "$1" = /* || "$1" = ./* || "$1" = ../* || "$1" = ~* ]]; then
          desc_file=${1}
        else
          desc_file="${_appsdefpath}/${1}.md"
        fi

        if [[ ! -f "$desc_file" ]]; then
            echo "No description file for '${1}' found in ${_appsdefpath}"
            return 2
        fi
    fi

    # Fuzzy app and section picker if no arguments
    if [[ -z "$1" || ( -n "$1" && -z "$2" ) ]]; then
        local action default_action pick
        if [[ -n "$1" ]]; then
            default_action=$(_find_default_section "$desc_file")
            if [[ -n "$default_action" ]]; then
                apps "$1" "$default_action"
                return
            fi
        fi
        # fallback to fuzzy picker if no default
        pick=($(_apps_fuzzy_pick "$1"))
        local pick_status=$?
        [[ ${#pick} -eq 0 || $pick_status -ne 0 ]] && return 1
        app="${pick[1]}"
        action="${pick[2]}"
        
        apps "$app" "$action" "${pick[3]}"

        return
    fi

    local background=0
    local interactive=0
    local args=()
    local arg_vars=()

    # Loop through all arguments and extract --arg NAME=VALUE
    local skip_next=0 nextarg kv
    for ((i=1; i<=$#; i++)); do
      if [[ ${skip_next} -eq 1 ]]; then
        skip_next=0
        continue
      fi
      arg="${@[i]}"
      if [[ "$arg" == "-bg" || "$arg" == "--background" ]]; then
        background=1
      elif [[ "$arg" == "-i" || "$arg" == "--interactive" ]]; then
        interactive=1
      elif [[ "$arg" == "--arg" ]]; then
        # support both '--arg NAME=VAL' and '--arg=NAME=VAL'
        nextarg="${@[i+1]}"
        if [[ "$nextarg" =~ "=" ]]; then
          arg_vars+=("$nextarg")
          skip_next=1
        fi
      elif [[ "$arg" == --arg=* ]]; then
        arg_vars+=("${arg#--arg=}")
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

    # get script and possible mode label
    local mode_label=""
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

    # Extract mode label (if any) and strip it from the script
    local firstline="${script%%$'\n'*}"
    local rest="${script#*$'\n'}"
    local mode_label=""

    if [[ "$firstline" =~ "^#__APPS_SH_MODE__=([a-zA-Z0-9_-]+)" ]]; then
        mode_label="${match[1]}"
        script="$rest"
    fi

    # shared section for variables
    local shared_script
    for shared_section in shared vars; do
      shared_script="$(_extract_apps_section_script "${shared_section}" "$desc_file")"
      if [[ -n "$shared_script" ]]; then
        eval "$shared_script"
      fi
    done

    # set arguments to override
    local name value
    if [[ ${#arg_vars[@]} -gt 0 ]]; then
      for kv in "${arg_vars[@]}"; do
        name="${kv%%=*}"
        value="${kv#*=}"
        export "$name"="$value"
      done
    fi

    # Determine execution mode: CLI flag overrides, otherwise use mode_label
    local run_background=0
    local run_interactive=0
    if (( background )); then
        run_background=1
    elif (( interactive )); then
        run_interactive=1
    elif [[ "$mode_label" == "background" ]]; then
        run_background=1
    elif [[ "$mode_label" == "interactive" ]]; then
        run_interactive=1
    fi

    #[[ -n "$used_block" ]] && echo "Executing ${action} for ${app} using section: ${used_block}" >&2
    if (( run_background )); then
      eval "$script" &
      bg_pid=$!
      #echo "Started in background (PID $bg_pid)"
      return 0
    else
      if (( run_interactive )); then
        eval "$script"
      else # (( run_evaluate ))
        output=$(eval "$script")
        exitcode=$?
        [ -n "$output" ] && echo "$output"
        return $exitcode
      fi
    fi 
}

if [[ $(dotini apps --get "apps.aliases") == true ]]; then
    alias a="apps"
    alias al="launcher"
    alias run="a ."

    if [ -d "${_appsdefpath}" ]; then
       apps list aliases
    fi
fi

function apps-launcher-widget() {
  zle -I
  apps
  print 
  zle reset-prompt 
}

function apps-launcher-command() {
  local pick
  pick=($(_apps_fuzzy_pick))
  [[ -z "$pick" ]] && return 1
  LBUFFER="apps ${pick[1]} ${pick[2]} ${pick[3]}"
  zle accept-line
}

if [[ $(dotini apps --get "apps.launcher") == true ]]; then
  shortcut=$(dotini apps --get "apps.shortcut")
  if [[ $shortcut == \^? ]]; then
    char=${shortcut#^}
    eval "shortcut=\$'\\C-$char'"
  fi

  # launcher (issues with tty)
  #zle -N apps-launcher-widget
  #bindkey "$shortcut" apps-launcher-widget

  # insert command (alternative)
  bindkey "$shortcut" self-insert
  zle -N apps-launcher-command
  bindkey "$shortcut" apps-launcher-command
fi


apps-desktop-install() {
  local appname="$1"
  local apptitle="$2"
  if [[ -z "$appname" || -z "$apptitle" ]]; then
    echo "Usage: apps-desktop-install <appname> <title>"
    return 1
  fi

  local desc_file="${_appsdefpath}/${appname}.md"

  local has_rundesktop=0
  if grep -Eq '^##\s+.*\brun-desktop\b' "$desc_file"; then
    has_rundesktop=1
  fi
  local use_terminal exec_line
  if [[ $has_rundesktop -eq 1 ]]; then
    use_terminal="false"
    exec_line="${HOME}/.dotfiles/bash/.local/bin/dot apps ${appname} desktop run"
  else
    use_terminal="true"
    exec_line="${HOME}/.dotfiles/bash/.local/bin/dot apps ${appname} run"
  fi

  local desktop_dir="${HOME}/.local/share/applications"
  local desktop_file="${desktop_dir}/dotfiles-apps-${appname}.desktop"

  mkdir -p "$desktop_dir"
  cat > "$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${apptitle}
Exec=${exec_line}
Icon=prompt-icon-128.png
Keywords=apps
Terminal=${use_terminal}
Categories=Utility;
EOF

  if ! notify-send "Exported" "$apptitle" > /dev/null 2>&1; then
    echo "Exported" "$apptitle"
  fi
  update-desktop-database ~/.local/share/applications/
}

apps-service-install() {
  local appname="$1"
  local apptitle="$2"
  if [[ -z "$appname" || -z "$apptitle" ]]; then
    echo "Usage: apps-service-install <appname> <title>"
    return 1
  fi

  local desc_file="${_appsdefpath}/${appname}.md"

  if ! grep -Eq '^##\s+.*\brun-service\b' "$desc_file"; then
    echo "Cannot export service: No 'run-service' section found in $desc_file"
    return 2
  fi

  local service_dir="${HOME}/.config/systemd/user"
  local service_name="dotfiles-apps-${appname}.service"
  local service_file="${service_dir}/${service_name}"

  mkdir -p "$service_dir"
  cat > "$service_file" <<EOF
[Unit]
Description=${apptitle}

[Service]
Type=simple
ExecStart=${HOME}/.dotfiles/bash/.local/bin/dot apps ${appname} service run

[Install]
WantedBy=default.target
EOF

  if ! notify-send "Exported" "$apptitle" > /dev/null 2>&1; then
    echo "Exported" ${service_name}
  fi
  systemctl --user daemon-reload
}
