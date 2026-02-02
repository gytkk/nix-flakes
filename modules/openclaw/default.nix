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
      defaultText = lib.literalExpression "inputs.nix-openclaw.packages.\${pkgs.system}.openclaw";
      description = "OpenClaw package to install";
    };
  };

  config = lib.mkIf cfg.enable {
    # Use lowPrio to avoid conflicts with nodejs's npm/npx
    home.packages = [ (lib.lowPrio cfg.package) ];

    # Create workspace directory
    home.file.".openclaw/.keep".text = "";

    home.shellAliases = {
      oclaw = "openclaw";
    };
  };
}
