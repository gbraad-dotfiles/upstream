apps_desktop_install() {
  local appname="$1"
  local apptitle="$2"
  if [[ -z "$appname" || -z "$apptitle" ]]; then
    echo "Usage: apps-desktop-install <appname> <title>"
    return 1
  fi

  local desc_file="${APPSREPO}/${appname}.md"

  local has_rundesktop=0
  if grep -Eq '^###\s+.*\brun-desktop\b' "$desc_file"; then
    has_rundesktop=1
  fi
  local use_terminal exec_line
  if [[ $has_rundesktop -eq 1 ]]; then
    use_terminal="false"
    exec_line="${HOME}/.dotfiles/bash/.local/bin/dot app ${appname} desktop run"
  else
    use_terminal="true"
    exec_line="${HOME}/.dotfiles/bash/.local/bin/dot app ${appname} run"
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

apps_service_install() {
  local appname="$1"
  local apptitle="$2"
  if [[ -z "$appname" || -z "$apptitle" ]]; then
    echo "Usage: apps-service-install <appname> <title>"
    return 1
  fi

  local desc_file="${APPSREPO}/${appname}.md"

  if ! grep -Eq '^###\s+.*\brun-service\b' "$desc_file"; then
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
ExecStart=${HOME}/.dotfiles/bash/.local/bin/dot app ${appname} service run

[Install]
WantedBy=default.target
EOF

  if ! notify-send "Exported" "$apptitle" > /dev/null 2>&1; then
    echo "Exported" ${service_name}
  fi
  systemctl --user daemon-reload
}
