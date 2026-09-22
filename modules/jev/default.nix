{
  config,
  lib,
  osConfig ? null,
  pkgs,
  ...
}:
let
  cfg = config.modules.jev;
  usesSystemAgenix = osConfig != null;
  secretPath =
    if usesSystemAgenix then
      osConfig.age.secrets.jev-api-key.path
    else
      config.age.secrets.jev-api-key.path;
in
{
  options.modules.jev.enable = lib.mkEnableOption "Jev API access with the agenix key";

  config = lib.mkIf cfg.enable {
    age.secrets = lib.mkIf (!usesSystemAgenix) {
      jev-api-key = {
        file = ../../secrets/jev-api-key.age;
        mode = "0400";
      };
    };

    home.packages = [
      (pkgs.writeShellApplication {
        name = "with-jev";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.replaceStrings [ "@secretPath@" ] [ (lib.escapeShellArg secretPath) ] (
          builtins.readFile ./with-jev.sh
        );
      })
    ];
  };
}
