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
      mise
      uv

      # IDEs
      neovim
      code-cursor

      # Dev tools
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

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig = {
      tools = {
        terraform = [
          "1.10.2"
          "1.12.2"
        ];
      };
    };
  };

  programs.home-manager.enable = true;
}
