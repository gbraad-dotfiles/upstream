if [[ $(dotini apps --get "apps.aliases") == true ]]; then
    alias a="app"
    alias as="apps"
    alias al="launcher"
    alias apps="app apps"

    if [ -d "${APPSREPO}" ]; then
       app list aliases
    fi
fi

function apps_launcher_widget() {
  zle -I
  apps
  print 
  zle reset-prompt 
}

function apps_launcher_command() {
  local pick
  pick=($(apps all))
  [[ -z "$pick" ]] && return 1
  LBUFFER="app ${pick[1]} ${pick[2]} ${pick[3]}"
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
  zle -N apps_launcher_command
  bindkey "$shortcut" apps_launcher_command
fi


