{ inputs, ... }:

{
  # 각 nixpkgs 버전을 pkgs.X로 접근 가능하게 하는 overlay
  # Lazy import: 실제 사용되는 패키지만 import하여 evaluation 시간 단축
  nixpkgs-versions =
    final: _prev:
    let
      # Lazy import helper - 패키지가 실제로 접근될 때만 nixpkgs를 import
      mkLazyPkgs =
        nixpkgsInput: packages:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value =
              (import nixpkgsInput {
                localSystem = final.stdenv.hostPlatform.system;
                config.allowUnfree = true;
              }).${name};
          }) packages
        );
    in
    {
      # stable-25_05: ruby_3_2, micromamba 사용
      stable-25_05 = mkLazyPkgs inputs.nixpkgs-25_05 [
        "ruby_3_2"
        "micromamba"
      ];

    };

  # 패키지 수정 overlay
  package-fixes = final: prev: {
    # databricks-cli 0.290.1: cmd/apps 테스트 실패 (upstream nixpkgs 문제)
    databricks-cli = prev.databricks-cli.overrideAttrs { doCheck = false; };

    notion-cli = final.callPackage ../packages/notion-cli/package.nix { };
    ntn = final.notion-cli;

    # omnigent - built from source via uv2nix (see packages/omnigent). The
    # uv2nix builders come from flake inputs, threaded in here.
    omnigent = final.callPackage ../packages/omnigent/package.nix {
      inherit (inputs) uv2nix pyproject-nix pyproject-build-systems;
    };

    # pup - Datadog CLI, packaged from upstream release binaries
    pup = final.callPackage ../packages/pup/package.nix { };
  };

  # Shared toolchains used across modules and hosts
  toolchains = final: _prev: {
    rustToolchain = final.rust-bin.stable.latest.default.override {
      extensions = [
        "rust-analyzer"
        "rust-src"
      ];
      targets = [
        "wasm32-wasip1"
      ];
    };
  };
}
