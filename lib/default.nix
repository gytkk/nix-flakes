{ inputs, nixpkgs }:
{
  builders = import ./builders.nix { inherit inputs nixpkgs; };
}