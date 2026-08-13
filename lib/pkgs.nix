{ inputs, nixpkgs }:
let
  repoOverlays = import ../overlays { inherit inputs; };
  flakeStoresOverlay =
    final: prev: builtins.removeAttrs (inputs.flake-stores.overlays.default final prev) [ "opencode" ];

  commonOverlays = [
    inputs.copyparty.overlays.default
    inputs.nix-zed-extensions.overlays.default
    flakeStoresOverlay
    inputs.niri.overlays.niri
    inputs.rust-overlay.overlays.default
    repoOverlays.nixpkgs-versions
    repoOverlays.toolchains
    repoOverlays.package-fixes
  ];

  systemPkgs = {
    "x86_64-linux" = import nixpkgs {
      localSystem = "x86_64-linux";
      config.allowUnfree = true;
      overlays = commonOverlays;
    };
    "aarch64-darwin" = import nixpkgs {
      localSystem = "aarch64-darwin";
      config.allowUnfree = true;
      overlays = commonOverlays;
    };
  };
in
{
  inherit commonOverlays systemPkgs;

  mkPkgs = system: systemPkgs.${system};

  mkSystemPkgs =
    systems:
    builtins.listToAttrs (
      map (system: {
        name = system;
        value = systemPkgs.${system};
      }) systems
    );
}
