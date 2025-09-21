#!/usr/bin/env zsh

# Candidate filenames for actionfile
actions_candidate_files=("Actionfile.md" "Actfile.md" "README.md")

# Find the actionfile in a given directory
actions_find_actionfile() {
  local dir="$1"
  for fname in "${actions_candidate_files[@]}"; do
    if [[ -f "$dir/$fname" ]]; then
      echo "$dir/$fname"
      return 0
    fi
  done
  return 1
}

# Extract all markdown sections mapping each header key to its body
actions_extract_action_sections() {
  local file="$1"
  awk '
    BEGIN {in_code=0; keys=""; body=""; mode=""; from_backticks=0}
    /^### / {
      if (keys != "" && body != "") {
        if (from_backticks) {
          print "SECTIONSTART"
          print "KEY:" keys
          print "MODE:" mode
          print "BODY:"
          printf "%s", body
          print "SECTIONEND"
        } else {
          n2 = split(keys, arr2, /[[:space:]]+/)
          for (j=1; j<=n2; j++) {
            print "SECTIONSTART"
            print "KEY:" arr2[j]
            print "MODE:" mode
            print "BODY:"
            printf "%s", body
            print "SECTIONEND"
          }
        }
      }
      # Single key inside backticks
      if (match($0, /`([^`]*)`/, m)) {
        keys = m[1]
        from_backticks = 1
      } else {
        keys = ""
        rest = substr($0, 5)
        n = split(rest, arr, /[[:space:]]+/)
        for (i=1; i<=n; i++) {
          if (match(arr[i], /^[A-Za-z-]+$/)) {
            if (keys != "") keys = keys " "
            keys = keys arr[i]
          } else {
            break
          }
        }
        from_backticks = 0
      }
      body = ""
      mode = ""
      in_code = 0
      next
    }
    /^```sh/ {
      in_code=1
      mode = ""
      if (match($0, /^```sh[[:space:]]+([a-zA-Z0-9_-]+)/, m)) {
        mode = m[1]
      }
      next
    }
    in_code && /^```/ {in_code=0; next}
    in_code {body = body $0 "\n"}
    END {
      if (keys != "" && body != "") {
        if (from_backticks) {
          print "SECTIONSTART"
          print "KEY:" keys
          print "MODE:" mode
          print "BODY:"
          printf "%s", body
          print "SECTIONEND"
        } else {
          n2 = split(keys, arr2, /[[:space:]]+/)
          for (j=1; j<=n2; j++) {
            print "SECTIONSTART"
            print "KEY:" arr2[j]
            print "MODE:" mode
            print "BODY:"
            printf "%s", body
            print "SECTIONEND"
          }
        }
      }
    }
  ' "$file"
}

# Extract config
actions_extract_config_block() {
  local file="$1"
  awk '
    BEGIN {in_config=0}
    /^### config/ {in_config=1; next}
    in_config && /^```ini/ {in_code=1; next}
    in_config && in_code && /^```/ {exit}
    in_config && in_code {print}
  ' "$file"
}

actions_parse_ini() {
  local file="$1"
  awk '
    BEGIN {section=""}
    /^\[([A-Za-z0-9_]+)\]$/ {match($0, /^\[([A-Za-z0-9_]+)\]$/, m); section=toupper(m[1]); next}
    /^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*"([^"]*)"/ {
      match($0, /^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*"([^"]*)"/, m);
      key=toupper(m[1]); value=m[2];
      printf "export %s_%s=\"%s\"\n", section, key, value;
      next
    }
    /^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*([^"]\S*)[[:space:]]*$/ {
      match($0, /^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*([^"]\S*)[[:space:]]*$/, m);
      key=toupper(m[1]); value=m[2];
      printf "export %s_%s=\"%s\"\n", section, key, value;
      next
    }
  ' "$file"
}

# Extract vars
actions_extract_vars_block() {
  local file="$1"
  awk '
    BEGIN {in_vars=0}
    /^### vars/ {in_vars=1; next}
    in_vars && /^```sh/ {in_code=1; next}
    in_vars && in_code && /^```/ {exit}
    in_vars && in_code {print}
  ' "$file"
}

action() {
  local shell="${ACTIONFILE_SHELL:-bash}"
  local search_dir=""
  local act=""
  local ctx=""
  local file=""
  local interactive=0
  local background=0
  local subshell=0
  local evaluate=0
  local sourced=0
  local list_mode=0
  local list_as_actions=0
  local -A arg_vars

  local i=1
  while (( i <= $# )); do
    if [[ "${@[i]}" == --shell=* ]]; then
      shell="${@[i]#--shell=}"
    elif [[ "${@[i]}" == "--arg" ]]; then
      ((i++))
      if [[ "${@[i]}" == *"="* ]]; then
        local kv="${@[i]}"
        local k="${kv%%=*}"
        local v="${kv#*=}"
        arg_vars[$k]="$v"
      fi
    elif [[ "${@[i]}" == --arg=* ]]; then
      local kv="${@[i]#--arg=}"
      local k="${kv%%=*}"
      local v="${kv#*=}"
      arg_vars[$k]="$v"
    elif [[ "${@[i]}" == "--interactive" ]]; then
      interactive=1
    elif [[ "${@[i]}" == "--background" ]]; then
      background=1
    elif [[ "${@[i]}" == "--subshell" ]]; then
      subshell=1
    elif [[ "${@[i]}" == "--evaluate" ]]; then
      evaluate=1
    elif [[ "${@[i]}" == "--sourced" ]]; then
      sourced=1
    elif [[ "${@[i]}" == "--list-sections" ]]; then
      list_mode=1
    elif [[ "${@[i]}" == "--list-actions" ]]; then
      list_mode=1
      list_as_actions=1
    elif [[ "${@[i]}" == "." || "${@[i]}" == */ || -d "${@[i]}" ]]; then
      search_dir="${@[i]}"
    elif [[ "${@[i]}" == *".md" ]]; then
      file="${@[i]}"
    elif [[ -z "$act" ]]; then
      act="${@[i]}"
    elif [[ -z "$ctx" ]]; then
      ctx="${@[i]}"
    fi
    ((i++))
  done

  # File resolution logic: always resolve file, even for --list
  if [[ -z "$file" ]]; then
    local dir="${search_dir:-.}"
    file=$(actions_find_actionfile "$dir")
    if [[ -z "$file" ]]; then
      echo "ERROR: No Actionfile.md, Actfile.md or README.md found in directory: $dir" >&2
      return 2
    fi
  elif [[ ! -f "$file" ]]; then
    echo "ERROR: File not found: $file" >&2
    return 2
  fi

  # If --list, print all available actions and exit
  if (( list_mode )); then
    local sectiondump
    sectiondump="$(actions_extract_action_sections "$file")"
    local keys=()
    local key=""
    while IFS= read -r line; do
      if [[ "$line" == SECTIONSTART ]]; then
        key=""
      elif [[ "$line" == KEY:* ]]; then
        key="${line#KEY:}"
        if (( list_as_actions )); then
          # dash-separated and no spaces: reverse order
          if [[ "$key" == *-* && "$key" != *" "* ]]; then
            context="${key%%-*}"
            action="${key#*-}"
            keys+=("$action $context")
          else
            keys+=("$key")
          fi
        else
          keys+=("$key")
        fi
      fi
    done < <(printf "%s\n" "$sectiondump")
    print -l "${keys[@]}"
    return 0
  fi

  # Set predefined variables
  local -A predefined_vars
  predefined_vars[FILENAME]="$file"
  predefined_vars[TITLE]="$(awk '/^# / {sub(/^# /,""); print; exit}' "$file")"
  local configblock setenv
  configblock="$(actions_extract_config_block "$file")"
  if [[ -n $configblock ]]; then
    setenv="$(printf '%s\n' "$configblock" | actions_parse_ini)"
  fi


  # Add predefined variables programmatically
  local varsblock
  varsblock="$(actions_extract_vars_block "$file")"
  for key in "${(@k)predefined_vars}"; do
    val="${predefined_vars[$key]}"
    varsblock="${varsblock}"$'\n'"${key}=\"${val//\"/\\\"}\""
  done

  # Apply --arg overrides
  for k v in "${(@kv)arg_vars}"; do
    # Remove any previous definition for this variable, then append the override
    varsblock=$(echo "$varsblock" | awk -v k="$k" '!($0 ~ "^"k"=") {print}')
    varsblock="${varsblock}"$'\n'"${k}=\"${v//\"/\\\"}\""
  done

  # Handle configdir and possible override config
  local configdir configname configfile setoverride
  configpath=${arg_vars[CONFIGPATH]}
  configname=${arg_vars[APPNAME]}
  configfile="${configpath}/${configname}.ini"
  if [[ -f "${configfile}" ]]; then
    setoverride="$(cat ${configfile} | actions_parse_ini)"
  fi

  # Parse action sections
  local -A sections_body sections_mode
  local key="" body="" mode="" in_body=0
  local sectiondump
  sectiondump="$(actions_extract_action_sections "$file")"
  while IFS= read -r line; do
    if [[ "$line" == SECTIONSTART ]]; then
      key=""
      body=""
      mode=""
      in_body=0
    elif [[ "$line" == KEY:* ]]; then
      key="${line#KEY:}"
      key="${key//[[:space:]]/}"
    elif [[ "$line" == MODE:* ]]; then
      mode="${line#MODE:}"
      mode="${mode//[[:space:]]/}"
    elif [[ "$line" == BODY:* ]]; then
      in_body=1
      body=""
    elif [[ "$line" == SECTIONEND ]]; then
      in_body=0
      if [[ -n "$key" ]]; then
        sections_body["$key"]="$body"
        sections_mode["$key"]="$mode"
      fi
    elif (( in_body )); then
      body+="$line"$'\n'
    fi
  done <<< "$sectiondump"

  local script=""
  local shared=""
  local execmode=""

  # Set action to "default" if none provided
  if [[ -z "$act" ]]; then
    act="default"
  fi

  # Backtick match: act ctx (e.g. make cross)
  if [[ -z "${script//[[:space:]]/}" && -n "$ctx" && -n "$act" ]]; then
    local joined="${act}${ctx}"
    script="${sections_body["$joined"]}"
    execmode="${sections_mode["$joined"]}"
  fi

  # Context match: ctx-act (e.g. background-run)
  if [[ -z "${script//[[:space:]]/}" && -n "$ctx" && -n "$act" ]]; then
    local composite="${ctx}-${act}"
    script="${sections_body["$composite"]}"
    execmode="${sections_mode["$composite"]}"
  fi

  # Direct match
  if [[ -z "${script//[[:space:]]/}" && -n "$act" ]]; then
    script="${sections_body["$act"]}"
    execmode="${sections_mode["$act"]}"
  fi

  # Fallback: error
  if [[ -z "${script//[[:space:]]/}" ]]; then
    echo "ERROR: Section \"${ctx:+$ctx-}$act\" not found and no suitable ctx-specific section available." >&2
    return 2
  fi

  # Get shared
  shared="${sections_body["shared"]}"
 
  # Set background/interactive from execmode (if not already forced by CLI)
  case "$execmode" in
    *subshell*)    subshell=1 ;;
    *evaluate*)    evaluate=1 ;;
    *sourced*)     sourced=1 ;;
    *background*)  background=1 ;;
    *interactive*) interactive=1 ;;
    *)             subshell=1 ;;        # default execution mode
  esac

  # Execution according to mode
  if (( background )); then
    nohup "$shell" <<EOF &>/dev/null &
$setenv
$varsblock
$setoverride
$shared
$script
EOF
  elif (( evaluate )); then
    eval "$setenv"
    eval "$varsblock"
    eval "$setoverride"
    eval "$shared"
    eval "$script"
  elif (( sourced )); then
    _tmpfile=$(mktemp)
    echo "$setenv" > $_tmpfile
    echo "$varsblock" >> $_tmpfile
    echo "$setoverride" >> $_tmpfile
    echo "$shared" >> $_tmpfile
    echo "$script" >> $_tmpfile
    source $_tmpfile
    rm -f $_tmpfile
  elif (( subshell )); then
    local output exitcode
    output=$(
      eval "$setenv"
      eval "$varsblock"
      eval "$setoverride"
      eval "$shared"
      eval "$script"
    )
    exitcode=$?
    [ -n "$output" ] && echo "$output"
    return $exitcode
   elif (( interactive )); then
    if [[ "$shell" == *zsh* ]]; then
      echo "WARNING: You selected zsh as the execution shell. Note: Running zsh in interactive mode (-i) with a heredoc will NOT execute the script input!"
      return 1
    fi

    "$shell" -i <<EOF
$setenv
$varsblock
$setoverride
$shared
$script
EOF
  fi
}

if [[ $(dotini apps --get "apps.aliases") == true ]]; then
  alias run="action ."
fi
