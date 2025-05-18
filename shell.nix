{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    pkgs.git
    pkgs.tailscale
    pkgs.screen
    pkgs.tmux
    pkgs.zsh
    pkgs.powerline
    pkgs.podman
    pkgs.stow
    pkgs.openssh
    pkgs.cadaver
    pkgs.python311
    pkgs.python311Packages.pip
  ];

  shellHook = ''
    export SHELL=$(which zsh)
    exec zsh
  '';
}
