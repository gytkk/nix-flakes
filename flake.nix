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
      pkgs = import nixpkgs {
        config.allowUnfree = true;

        system = "x86_64-linux"; # Default system, can be overridden in configurations

        overlays = [
          inputs.nix-vscode-extensions.overlays.default
        ];
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
          inherit pkgs;
          extraSpecialArgs = {
            system = "aarch64-darwin";
          };
          modules = [
            ./home.nix
          ];
        };

        "devsisters-macstudio" = inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            system = "aarch64-darwin";
          };
          modules = [
            ./home.nix
          ];
        };

        "wsl-ubuntu" = inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            system = "x86_64-linux";
            username = "gytkk";
            homeDirectory = "/home/gytkk";

            zsh-powerlevel10k = inputs.zsh-powerlevel10k;
          };
          modules = [
            ./home.nix
            ./modules/git
          ];
        };
      };
    };
}
