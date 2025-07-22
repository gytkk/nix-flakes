{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  extraPackages ? (_: [ ]),
  ...
}:

let
  eclair = pkgs.writeShellScriptBin "ecl" ''
    export PATH="/Users/gyutak/.gem/ruby/3.1.0/bin:${pkgs.ruby_3_1}/bin:${pkgs.tmux}/bin:$PATH"
    export GEM_PATH="${pkgs.ruby_3_1}/lib/ruby/gems/3.1.0:/Users/gyutak/.gem/ruby/3.1.0"
    export GEM_HOME="/Users/gyutak/.gem/ruby/3.1.0"

    # Install eclair gem if not present
    if ! ${pkgs.ruby_3_1}/bin/gem list ecl -i > /dev/null 2>&1; then
      echo "Installing eclair gem..."
      ${pkgs.ruby_3_1}/bin/gem install ecl --version 3.0.4 --user-install --no-document 2>/dev/null
    fi

    # Execute the actual ecl command
    exec "/Users/gyutak/.gem/ruby/3.1.0/bin/ecl" "$@"
  '';

  # Generate terraform version aliases dynamically based on terraform module config
  terraformVersionAliases =
    lib.mkIf (config.modules.terraform.enable && config.modules.terraform.installAll)
      (
        builtins.listToAttrs (
          map (version: {
            name = "tf-${builtins.replaceStrings [ "." ] [ "" ] version}";
            value = "AWS_PROFILE=saml terraform-${version}";
          }) config.modules.terraform.versions
        )
      );
in
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

    # 기본 패키지 + Devsisters 특화 패키지
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

        # Devsisters 특화 패키지들
        # Authentication
        saml2aws
        vault

        # Required dependencies for eclair
        eclair
        ruby_3_1
        ncurses.dev

        # Databricks
        databricks-cli

        # Custom scripts
        (pkgs.writeShellScriptBin "sign" (builtins.readFile ./scripts/sign))
        (pkgs.writeShellScriptBin "login" (builtins.readFile ./scripts/login))
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

  # Devsisters 특화 shell aliases
  home.shellAliases = {
    tf = "AWS_PROFILE=saml terraform";
  } // terraformVersionAliases;

  # Devsisters 특화 환경 변수
  home.sessionVariables = {
    VAULT_ADDR = "https://vault.devsisters.cloud";
  };
}