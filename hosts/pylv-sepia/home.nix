{ pkgs, ... }:

{
  home.username = "gytkk";
  home.homeDirectory = "/home/gytkk";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # CLI utilities
    htop
    tmux
    ripgrep
    fd
    jq

    # Development
    git
    vim
  ];

  programs.home-manager.enable = true;
}
