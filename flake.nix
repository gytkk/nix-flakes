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

    # ===== Zsh plugins =====
    # zsh-powerlevel10k - for zsh theme
    zsh-powerlevel10k = {
      url = "github:romkatv/powerlevel10k/v1.20.0";
      flake = false;
    };

    # ===== VS Code =====
    # nix-vscode-extensions - for VS Code extensions from marketplace
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      # 라이브러리 import
      myLib = import ./lib { inherit inputs nixpkgs; };
      
      # 시스템별 패키지
      pkgs = myLib.builders.mkSystemPkgs [ "x86_64-linux" "aarch64-darwin" ];

      # 환경별 설정 정의
      environmentConfigs = {
        "devsisters-macbook" = {
          system = "aarch64-darwin";
          username = "gyutak";
          homeDirectory = "/Users/gyutak";
          extraModules = [ ./modules/devsisters ];
        };
        "devsisters-macstudio" = {
          system = "aarch64-darwin";
          username = "gyutak";
          homeDirectory = "/Users/gyutak";
          extraModules = [ ./modules/devsisters ];
        };
        "wsl-ubuntu" = {
          system = "x86_64-linux";
          username = "gytkk";
          homeDirectory = "/home/gytkk";
          extraModules = [];
        };
      };

      # 공통 설정
      commonSpecialArgs = {
        zsh-powerlevel10k = inputs.zsh-powerlevel10k;
      };

      baseModules = [ ./home.nix ];

      # 홈 설정 생성 함수
      mkHomeConfig = myLib.builders.mkHomeConfig {
        inherit environmentConfigs commonSpecialArgs baseModules;
      };
    in {
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

        "wsl-ubuntu" = inputs.nix-darwin.lib.darwinSystem {
          system = "x86_64-linux";
          modules = [
          ];
        };
      };

      homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;
    };
}
