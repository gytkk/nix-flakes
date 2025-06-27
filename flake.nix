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

      homeConfigurations = {
        "devsisters-macbook" = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs.aarch64-darwin;
          extraSpecialArgs = {
            system = "aarch64-darwin";
            username = "gyutak";
            homeDirectory = "/Users/gyutak";

            zsh-powerlevel10k = inputs.zsh-powerlevel10k;
          };
          modules = [
            ./home.nix
            ./modules/devsisters
          ];
        };

        "devsisters-macstudio" = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs.aarch64-darwin;
          extraSpecialArgs = {
            system = "aarch64-darwin";
            username = "gyutak";
            homeDirectory = "/Users/gyutak";

            zsh-powerlevel10k = inputs.zsh-powerlevel10k;
          };
          modules = [
            ./home.nix
            ./modules/devsisters
          ];
        };

        "wsl-ubuntu" = inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = pkgs.x86_64-linux;
          extraSpecialArgs = {
            system = "x86_64-linux";
            username = "gytkk";
            homeDirectory = "/home/gytkk";

            zsh-powerlevel10k = inputs.zsh-powerlevel10k;
          };
          modules = [
            ./home.nix
          ];
        };
      };
    };
}
