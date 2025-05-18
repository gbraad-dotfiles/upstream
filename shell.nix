{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  buildInputs = [
    (pkgs.vim_configurable.override {
      python3 = pkgs.python3;
    })
    pkgs.git
    pkgs.tailscale
    pkgs.screen
    pkgs.tmux
    pkgs.zsh
    pkgs.podman
    pkgs.stow
    pkgs.openssh
    pkgs.ranger
    pkgs.cadaver
    pkgs.python311
    pkgs.python311Packages.pip
  ];

  shellHook = ''
    export SHELL=$(which zsh)
    exec zsh
  '';
}
