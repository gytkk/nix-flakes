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
      inputs.rust-overlay.follows = "rust-overlay";
    };

    # rust-overlay - reproducible Rust toolchains without rustup
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
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

    # 미리 빌드된 바이너리가 없는 omnigent는 커밋된 uv.lock을 사용해
    # packages/omnigent에서 uv2nix로 빌드한다.
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # kc2aws - Keycloak OIDC→SAML CLI authenticator (Devsisters 전용, private repo → SSH)
    keycloak2aws = {
      url = "git+ssh://git@github.com/devsisters/keycloak2aws";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # wg-cli - Devsisters WireGuard VPN CLI (Devsisters 전용, private repo → SSH)
    devsisters-wg = {
      url = "git+ssh://git@github.com/devsisters/wg";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "gws/flake-utils";
    };

    # gws - Google Workspace CLI
    gws = {
      url = "github:googleworkspace/cli";
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
    { nixpkgs, ... }@inputs:
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

      homeConfigurations = builtins.mapAttrs mkHomeConfig environmentConfigs;
      nixosConfigurations = builtins.mapAttrs mkNixOSConfig hostConfigs;

      runtimeGoldenHashes = import ./agent-core/nix/runtime-golden-hashes.nix;
      mkAgentCoreOutputs =
        systemPkgs: golden:
        let
          render = import ./agent-core/nix/render.nix { pkgs = systemPkgs; };
          hashFor = runtime: if golden then runtimeGoldenHashes.${runtime} else null;
        in
        {
          openclaw = render {
            outputHash = hashFor "openclaw";
            runtime = "openclaw";
          };
          claude = render {
            outputHash = hashFor "claude";
            runtime = "claude";
          };
          codex = render {
            outputHash = hashFor "codex";
            runtime = "codex";
            runtimeSkillRoots = [ ./modules/codex/skills ];
          };
          pi = render {
            outputHash = hashFor "pi";
            runtime = "pi";
            runtimeSkillRoots = [ ./modules/pi/skills ];
          };
        };
      agentCoreOutputs = builtins.mapAttrs (_: systemPkgs: mkAgentCoreOutputs systemPkgs false) pkgs;
      agentCoreGoldenOutputs = builtins.mapAttrs (_: systemPkgs: mkAgentCoreOutputs systemPkgs true) pkgs;

      agentCoreSourcesMatch =
        system:
        let
          output = agentCoreOutputs.${system};
          homeName = if system == "aarch64-darwin" then "devsisters-macbook" else "pylv-denim";
          homeFiles = homeConfigurations.${homeName}.config.home.file;
          commonMatches = [
            (toString homeFiles.".claude/CLAUDE.md".source == "${output.claude}/CLAUDE.md")
            (toString homeFiles.".claude/skills".source == "${output.claude}/skills")
            (toString homeFiles.".codex/AGENTS.md".source == "${output.codex}/AGENTS.md")
            (toString homeFiles.".pi/agent/AGENTS.md".source == "${output.pi}/AGENTS.md")
            (toString homeFiles.".pi/agent/APPEND_SYSTEM.md".source == "${output.pi}/APPEND_SYSTEM.md")
            (toString homeFiles.".pi/agent/skills".source == "${output.pi}/skills")
          ];
          onyx = nixosConfigurations.pylv-onyx.config;
          onyxHomeFiles = onyx.home-manager.users.gytkk.home.file;
          linuxMatches = [
            (
              toString onyxHomeFiles.".openclaw/managed/agent-core/AGENTS.core.md".source
              == "${output.openclaw}/AGENTS.core.md"
            )
            (toString onyxHomeFiles.".openclaw/skills".source == "${output.openclaw}/skills")
            (toString onyx.environment.etc."codex/skills".source == "${output.codex}/skills")
          ];
        in
        builtins.all (matches: matches) (
          commonMatches ++ nixpkgs.lib.optionals (system == "x86_64-linux") linuxMatches
        );

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
        agent-core = systemPkgs.agent-core;
        notion-cli = systemPkgs.notion-cli;
        ntn = systemPkgs.ntn;
        omnigent = systemPkgs.omnigent;
        pup = systemPkgs.pup;
      }) pkgs;

      defaultApps = builtins.mapAttrs (system: _: {
        default = {
          type = "app";
          program = "${defaultPackages.${system}.default}/bin/nix-flakes";
        };
        agent-core = {
          type = "app";
          program = "${defaultPackages.${system}.agent-core}/bin/agent-core";
        };
      }) pkgs;

      checks = builtins.mapAttrs (system: systemPkgs: {
        agent-core = systemPkgs.agent-core;
        agent-core-renders =
          assert agentCoreSourcesMatch system;
          systemPkgs.runCommand "agent-core-render-check"
            {
              nativeBuildInputs = with systemPkgs; [
                agent-core
                nodejs
              ];
            }
            ''
              agent-core check
              node --test ${./modules/openclaw}/tests/agent-core-context.test.js
              test -d ${agentCoreGoldenOutputs.${system}.openclaw}/skills
              test -d ${agentCoreGoldenOutputs.${system}.claude}/skills
              test -d ${agentCoreGoldenOutputs.${system}.codex}/skills/devils-advocate
              test -d ${agentCoreGoldenOutputs.${system}.pi}/skills/pi-agent
              touch "$out"
            '';
      }) pkgs;
    in
    {
      packages = defaultPackages;
      apps = defaultApps;
      inherit checks;

      inherit homeConfigurations nixosConfigurations;
    };
}
