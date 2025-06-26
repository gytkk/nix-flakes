{ config, pkgs, system, username, homeDirectory, zsh-powerlevel10k, ... }:

{
  imports = [
    ./modules/zsh    
  ];

  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = true;
  };

  # Disable news on update
  news.display = "silent";

  home = {
    inherit username homeDirectory;

    # Set language for shell sessions managed by home-manager
    language = {
      base = "en_US.UTF-8";
    };

    packages = with pkgs; [
      # System utilities
      coreutils
      findutils

      # Development
      uv
      nodejs

      # IDEs
      code-cursor

      # Dev tools
      terraform
      awscli2
      yq

      # Kubernetes tools
      kubectl
      kubectx
      k9s

      # Zsh
      zsh-powerlevel10k

      # etc
      direnv
    ];

    stateVersion = "25.05";
  };

  programs.home-manager.enable = true;
}
