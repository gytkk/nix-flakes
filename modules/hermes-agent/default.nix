{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.modules.hermes-agent;
  hermesPackage = inputs.hermes-agent.packages.${config.nixpkgs.hostPlatform.system}.default;
  defaultHermesHome = "${config.home.homeDirectory}/.hermes";
  serviceHermesHome = "${config.home.homeDirectory}/.hermes-service/.hermes";
  hermesHome = if cfg.useServiceHome then serviceHermesHome else defaultHermesHome;
in
{
  options.modules.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent CLI";

    useServiceHome = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use ~/.hermes-service/.hermes as the default HERMES_HOME for CLI sessions.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ hermesPackage ];

    home.sessionVariables = {
      HERMES_HOME = hermesHome;
    };
  };
}
