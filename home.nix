{ config, pkgs, system, username, homeDirectory, zsh-powerlevel10k, ... }:

{
  imports = [
    ./modules/claude
    ./modules/git
    ./modules/zsh
  ];

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
      docker
      uv
      nodejs

      # IDEs
      neovim
      code-cursor

      # Dev tools
      awscli2
      yq
      ripgrep

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
