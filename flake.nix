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

    # nix-darwin - use master for unstable
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # ===== Zsh plugins =====
    zsh-powerlevel10k = {
      url = "github:romkatv/powerlevel10k/v1.20.0";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, darwin, zsh-powerlevel10k, ... }:
    let
      # 각 환경별 설정 정의
      environments = {
        macbook = {
          system = "aarch64-darwin";
          username = "gyutak";
          homeDirectory = "/Users/gyutak";
        };

        macstudio = {
          system = "aarch64-darwin";
          username = "gyutak";
          homeDirectory = "/Users/gyutak";
        };

        wsl-ubuntu = {
          system = "x86_64-linux";
          username = "gytkk";
          homeDirectory = "/home/gytkk";
        };
      };

      # 각 환경별 Home Manager 설정 생성 함수
      mkHomeConfiguration = name: config: 
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${config.system};
          extraSpecialArgs = { 
            inherit (config) system username;
            homeDirectory = config.homeDirectory;
          };
          modules = [
            ./home.nix
          ];

          extraSpecialArgs = {
            inherit zsh-powerlevel10k;
          };
        };
    in {
      # 각 환경별 homeConfigurations 생성
      homeConfigurations = builtins.mapAttrs mkHomeConfiguration environments;
    };
}
