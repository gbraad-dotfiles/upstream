if [[ $(dotini launcher --get "launcher.aliases") == true ]]; then
    dotini launcher --list | grep '^aliases\.' | sed 's/^aliases\.//g' | while read -r toalias; do
      alias $toalias
    done

    if [ -d "${APPSREPO}" ]; then
       app list aliases
    fi
    if [ -d "${ACTPATH}" ]; then
       app actionfiles aliases
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

if [[ $(dotini launcher --get "launcher.enabled") == true ]]; then
  shortcut=$(dotini launcher --get "launcher.shortcut")
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


