{ inputs, nixpkgs }:
{
  builders = import ./builders.nix { inherit inputs nixpkgs; };
  environments = import ./environments.nix { pkgs = nixpkgs; lib = nixpkgs.lib; };
}