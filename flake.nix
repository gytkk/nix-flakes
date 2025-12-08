{
  description = "Home Manager and NixOS configuration";

  inputs = {
    # Nix 패키지 모음
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";
    nixpkgs-24_05.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-25_05.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-25_11.url = "github:nixos/nixpkgs/nixos-25.11";

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

    # nix-darwin
    # nix-darwin = {
    #   url = "github:nix-darwin/nix-darwin/master";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # nixpkgs-terraform - for Terraform version management
    # XXX: Pinned to specific commit to avoid infinite recursion issues
    nixpkgs-terraform = {
      url = "github:stackbuilders/nixpkgs-terraform/67111c56b525073991fcb656ce30e9ad25a78826";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-vscode-extensions - for VSCode extension management
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
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

      # NixOS 설정에서 사용할 특수 인자
      specialArgs = {
        inherit inputs;
        username = "gytkk";
        homeDirectory = "/home/gytkk";
        isWSL = false;
      };

      # Overlays for NixOS
      nixosOverlays = [
        inputs.nixpkgs-terraform.overlays.default
        (import ./overlays { inherit inputs; }).nixpkgs-versions
      ];
    in
    {
      homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;

      # NixOS configurations
      nixosConfigurations = {
        pylv-sepia = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = specialArgs;
          modules = [
            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            ./hosts/pylv-sepia/configuration.nix
            {
              nixpkgs.overlays = nixosOverlays;
              nixpkgs.config.allowUnfree = true;

              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.extraSpecialArgs = specialArgs;
              home-manager.users.gytkk = import ./base/pylv/home.nix;
            }
          ];
        };
      };
    };
}
