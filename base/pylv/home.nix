{
  config,
  pkgs,
  username,
  homeDirectory,
  extraPackages ? (_: [ ]),
  ...
}:

{
  imports = [
    # 기본 모듈들 (항상 import됨)
    ../../modules/claude
    ../../modules/git
    ../../modules/terraform
    ../../modules/vim
    ../../modules/zsh
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
    packages =
      with pkgs;
      [
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

        # Secrets
        _1password-cli

        # etc
        direnv

        # Pylv 특화 패키지들 (추후 필요시 추가)
      ]
      ++ (extraPackages pkgs); # 환경별 추가 패키지

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

  # Pylv 특화 shell aliases (추후 필요시 추가)
  home.shellAliases = {
    # 추후 필요한 별칭들 추가 예정
  };

  # Pylv 특화 환경 변수 (추후 필요시 추가)
  home.sessionVariables = {
    # 추후 필요한 환경 변수들 추가 예정
  };
}