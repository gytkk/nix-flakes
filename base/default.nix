{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  inputs,
  ...
}:

let
  pkgs-master = import inputs.nixpkgs-master {
    system = pkgs.system;
    config.allowUnfree = true;
  };
  pkgs-24_05 = import inputs.nixpkgs-24_05 {
    system = pkgs.system;
    config.allowUnfree = true;
  };
in
{
  imports = [
    # 기본 모듈들 (항상 import됨)
    ../modules/claude
    ../modules/git
    ../modules/java
    ../modules/terraform
    ../modules/vim
    ../modules/zsh
  ];

  # Disable news on update
  news.display = "silent";

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
      pkgs-master.antigravity
      vscode
      docker
      gcc

      # Dev tools
      awscli2
      jq
      yq-go # yq 패키지는 더 이상 관리되지 않음
      ripgrep
      tmux
      less
      lazygit

      # Python
      uv

      # JavaScript + Node.js
      nodejs
      typescript
      pnpm
      pkgs-24_05.turbo

      # Go
      go

      # Kubernetes
      kubectl
      kubectx
      k9s
      kubernetes-helm

      # Secrets
      _1password-cli

      # etc
      direnv
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
