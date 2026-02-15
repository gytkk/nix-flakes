{
  description = "Home Manager and NixOS configuration";

  inputs = {
    # Nix 패키지 모음
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-25_05.url = "github:nixos/nixpkgs/nixos-25.05";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Disko - declarative disk partitioning
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixpkgs-terraform - for Terraform version management
    nixpkgs-terraform = {
      url = "github:stackbuilders/nixpkgs-terraform";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-vscode-extensions - for VSCode extension management
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-zed-extensions - for Zed extension management
    nix-zed-extensions = {
      url = "github:DuskSystems/nix-zed-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # agenix - secrets management for NixOS
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Rosé Pine themes
    rose-pine-ghostty = {
      url = "github:rose-pine/ghostty";
      flake = false;
    };

    # Catppuccin themes
    catppuccin-ghostty = {
      url = "github:catppuccin/ghostty";
      flake = false;
    };

    # copyparty - file server
    copyparty = {
      url = "github:9001/copyparty";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-openclaw - AI assistant gateway
    # NOTE: Currently broken due to pnpm dependency issue (hasown module missing)
    # See: https://github.com/openclaw/nix-openclaw/issues/45
    nix-openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    opencode-flake = {
      url = "github:gytkk/flake-stores";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # claude-code - AI coding assistant (always up-to-date)
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      # 라이브러리 import
      lib = import ./lib { inherit inputs nixpkgs; };

      # 시스템별 패키지
      pkgs = lib.builders.mkSystemPkgs [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      # 환경별 설정 (라이브러리에서 자동 로드)
      environmentConfigs = lib.environments.allEnvironments;
      hostConfigs = lib.environments.allHosts;

      baseModules = [ ./home.nix ];

      # 홈 설정 생성 함수
      mkHomeConfig = lib.builders.mkHomeConfig {
        inherit baseModules;
      };

      # NixOS 설정 생성 함수
      mkNixOSConfig = lib.builders.mkNixOSConfig;
    in
    {
      homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;

      nixosConfigurations = builtins.mapAttrs mkNixOSConfig hostConfigs;
    };
}
