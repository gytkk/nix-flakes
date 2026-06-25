{ inputs, ... }:

{
  imports = [
    inputs.agenix.nixosModules.default
    ./baseline.nix
    ./remote-access.nix
    ./secrets.nix
    ./user.nix
    ../codex/system.nix
  ];
}
