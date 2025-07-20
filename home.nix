{
  config,
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  imports = [
    # 기본 모듈들 (항상 import됨)
    ./modules/claude
    ./modules/git
    ./modules/terraform
    ./modules/vim
    ./modules/zsh
    # devsisters 모듈은 features.devsisters = true인 환경에서만 import됨
  ];

  # Disable news on update
  news.display = "silent";

  home = {
    inherit username homeDirectory;

    # Set language for shell sessions managed by home-manager
    language = {
      base = "ko_KR.UTF-8";
    };

    # 별도의 설정이 필요한 경우는 modules 디렉토리에 추가한다
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

      # Python
      uv

      # JavaScript + Node.js
      nodejs
      typescript
      pnpm
      turbo

      # Go
      go

      # Kubernetes
      kubectl
      kubectx
      k9s
      kubernetes-helm

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
