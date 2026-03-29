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
    ../modules/codex
    ../modules/ghostty
    ../modules/git
    ../modules/k9s
    ../modules/lsp
    ../modules/vim
    ../modules/zed
    ../modules/zsh
  ];

  # Disable news on update
  news.display = "silent";

  # macOS: App Management 권한 문제 방지
  # stateVersion >= 25.11에서 copyApps가 기본 활성화되며,
  # 매 switch마다 tccutil reset으로 TCC App Management 권한을 리셋함
  # Nix로 .app 번들을 설치하지 않으므로 비활성화
  targets.darwin.copyApps.enable = false;

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
      nixfmt

      # System utilities
      coreutils
      findutils
      gnupg
      libiconv

      # Development (common)
      docker
      gcc

      # Dev tools
      awscli2
      jq
      yq-go # yq 패키지는 더 이상 관리되지 않음
      fd
      ripgrep
      tmux
      zellij
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
      ruff

      # Rust
      rustup

      # JavaScript + Node.js
      bun
      nodejs
      typescript

      # Go
      go

      # Kubernetes
      kubectl
      kubectx
      kubernetes-helm

      # Secrets
      _1password-cli
      keybase
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default

      # Modeling
      ffmpeg
      imagemagick
      pkgs.stable-25_05.micromamba
      yt-dlp

      # etc
      direnv

      # Fonts
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      sarasa-gothic
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
    ];

    stateVersion = "26.05";

    # Rust/C 빌드 시 라이브러리 경로 (특히 macOS에서 libiconv 링킹용)
    sessionVariables = {
      LIBRARY_PATH = lib.makeLibraryPath [ pkgs.libiconv ];
    };
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
