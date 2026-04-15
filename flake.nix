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

    # nix-darwin - macOS system configuration
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
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

    flake-stores = {
      url = "github:gytkk/flake-stores";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # gws - Google Workspace CLI
    gws = {
      url = "github:googleworkspace/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Zen Browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # niri - scrollable tiling Wayland compositor
    niri.url = "github:sodiboo/niri-flake";

    # DankMaterialShell - all-in-one desktop shell for niri
    dms = {
      url = "github:AvengeMedia/DankMaterialShell";
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

      # 홈 설정 생성 함수
      mkHomeConfig = lib.builders.mkHomeConfig {
        baseModules = [ ];
      };

      # NixOS 설정 생성 함수
      mkNixOSConfig = lib.builders.mkNixOSConfig;

      mkDefaultCompatPackage =
        system: systemPkgs:
        let
          recommendedTargets =
            if system == "aarch64-darwin" then
              ''
                nix build .#homeConfigurations.devsisters-macbook.activationPackage
                nix build .#homeConfigurations.devsisters-macstudio.activationPackage
              ''
            else
              ''
                nix build .#nixosConfigurations.pylv-onyx.config.system.build.toplevel
                nix build .#nixosConfigurations.pylv-sepia.config.system.build.toplevel
              '';
        in
        systemPkgs.writeShellScriptBin "nix-flakes" ''
          cat <<'EOF'
          This flake does not expose a single real build target by default.
          Use an explicit attribute instead.

          Recommended targets:
          ${recommendedTargets}

          See also:
            nix flake show
          EOF
        '';

      defaultPackages = builtins.mapAttrs (system: systemPkgs: {
        default = mkDefaultCompatPackage system systemPkgs;
      }) pkgs;

      defaultApps = builtins.mapAttrs (system: _: {
        default = {
          type = "app";
          program = "${defaultPackages.${system}.default}/bin/nix-flakes";
        };
      }) pkgs;
    in
    {
      packages = defaultPackages;
      apps = defaultApps;

      homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;

      nixosConfigurations = builtins.mapAttrs mkNixOSConfig hostConfigs;
    };
}
