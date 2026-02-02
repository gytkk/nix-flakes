{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.modules.openclaw;
  openclawPkgs = inputs.nix-openclaw.packages.${pkgs.system};
in
{
  options.modules.openclaw = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable OpenClaw AI assistant";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = openclawPkgs.openclaw;
      description = "OpenClaw package to install";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Create workspace directory
    home.file.".openclaw/.keep".text = "";

    home.shellAliases = {
      oclaw = "openclaw";
    };
  };
}
