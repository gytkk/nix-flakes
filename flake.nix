{
  description = "Home Manager configuration";

  inputs = {
    # Nix 패키지 모음
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs/master";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager/master";
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
      homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;
    };
}
