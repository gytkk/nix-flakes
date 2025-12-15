{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  inputs,
  isWSL ? false,
  ...
}:

{
  imports = [
    # 기본 모듈들 (항상 import됨)
    ../modules/claude
    ../modules/ghostty
    ../modules/git
    ../modules/java
    ../modules/k9s
    ../modules/terraform
    ../modules/vim
    ../modules/vscode
    ../modules/zsh
  ];

  # Disable news on update
  news.display = "silent";

  # XDG Base Directory Specification
  xdg = {
    enable = true;
    configHome = "${homeDirectory}/.config";
  };

  home = {
    inherit username homeDirectory;

    # Set language for shell sessions managed by home-manager
    language = {
      base = "ko_KR.UTF-8";
    };

    # 기본 패키지 (모든 환경에서 공통)
    packages = with pkgs; [
      # Nix
      nixfmt-rfc-style

      # System utilities
      coreutils
      findutils

      # Development (common)
      docker
      gcc

      # Dev tools
      awscli2
      jq
      yq-go # yq 패키지는 더 이상 관리되지 않음
      ripgrep
      tmux
      less
      wget
      curl

      # Git
      git
      gh
      lazygit
      delta
      bat

      # Python
      uv

      # Rust
      rustup

      # JavaScript + Node.js
      nodejs
      typescript
      pnpm
      pkgs.stable-24_05.turbo

      # Go
      go

      # Kubernetes
      kubectl
      kubectx
      kubernetes-helm

      # Secrets
      _1password-cli

      # Modeling
      ffmpeg_7-full
      pkgs.stable-25_05.micromamba
      yt-dlp

      # etc
      direnv

      # Fonts
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      sarasa-gothic
    ];

    stateVersion = "25.05";
  };

  programs = {
    # Enable Home Manager
    home-manager = {
      enable = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
