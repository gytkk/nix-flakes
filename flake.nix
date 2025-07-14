{
  description = "Home Manager configuration";

  inputs = {
    # Nix 패키지 모음
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-darwin
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ===== VS Code =====
    # nix-vscode-extensions - for VS Code extensions from marketplace
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixpkgs-terraform - for Terraform version management
    nixpkgs-terraform = {
      url = "github:stackbuilders/nixpkgs-terraform";
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

      baseModules = [ ./home.nix ];

      # 홈 설정 생성 함수
      mkHomeConfig = lib.builders.mkHomeConfig {
        inherit baseModules;
      };
    in
    {
      darwinConfigurations = {
        "devsisters-macbook" = inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
          ];
        };

        "devsisters-macstudio" = inputs.nix-darwin.lib.darwinSystem {
          system = "aarch64-darwin";
          modules = [
          ];
        };
      };

      homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;
    };
}
