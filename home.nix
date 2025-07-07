{
  config,
  pkgs,
  username,
  homeDirectory,
  ...
}:

{
  imports = [
    ./modules/claude
    ./modules/git
    ./modules/vim
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

    # 별도의 설정이 필요한 경우는 modules 디렉토리에 추가한다
    packages = with pkgs; [
      # Nix
      nixfmt-rfc-style

      # System utilities
      coreutils
      findutils

      # Development (common)
      mise
      docker

      # Dev tools
      awscli2
      yq
      ripgrep

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
