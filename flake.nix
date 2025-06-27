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
      # 패키지 생성 헬퍼 함수
      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          inputs.nix-vscode-extensions.overlays.default
        ];
      };

      pkgs = {
        "x86_64-linux" = mkPkgs "x86_64-linux";
        "aarch64-darwin" = mkPkgs "aarch64-darwin";
      };

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

      # Home Configuration 헬퍼 함수
      mkHomeConfig = name: config:
        let
          requiredFields = [ "system" "username" "homeDirectory" ];
          missingFields = builtins.filter (field: !(builtins.hasAttr field config)) requiredFields;
        in
          if missingFields != []
          then throw "Missing required fields for ${name}: ${builtins.toString missingFields}"
          else inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = pkgs.${config.system};
            extraSpecialArgs = commonSpecialArgs // {
              inherit (config) system username homeDirectory;
            };
            modules = baseModules ++ (config.extraModules or []);
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
