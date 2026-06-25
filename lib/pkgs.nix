{ inputs, nixpkgs }:
let
  repoOverlays = import ../overlays { inherit inputs; };

  commonOverlays = [
    inputs.copyparty.overlays.default
    inputs.nix-zed-extensions.overlays.default
    inputs.flake-stores.overlays.default
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
