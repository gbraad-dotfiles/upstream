#!/bin/zsh

alias login-ghcr='podman login ghcr.io -u USERNAME -p $(secrets get ghcr_pat)'

_install_gh_debian() {
  sudo mkdir -p -m 755 /etc/apt/keyrings \
  out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  sudo apt update \
  sudo apt install gh -y
}

_install_gh_fedora() {
  # DNF5
  sudo dnf install dnf5-plugins
  sudo dnf config-manager addrepo --from-repofile=https://cli.github.com/packages/rpm/gh-cli.repo
  sudo dnf install gh --repo gh-cli
}

_install_gh_centos() {
  # DNF4
  sudo dnf install 'dnf-command(config-manager)'
  sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
  sudo dnf install gh --repo gh-cli
}

_install_gh() {
  source /etc/os-release
  case "$ID" in
    "fedora")
      _install_gh_fedora
      ;;
    "debian" | "ubuntu")
      _install_gh_debian
      ;;
    "centos" | "rhel")
      _install_gh_centos
      ;;
  esac
}
alias install-gh=_install_gh
