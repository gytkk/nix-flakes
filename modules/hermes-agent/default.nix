{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.modules.hermes-agent;
  hermesPackage = inputs.hermes-agent.packages.${config.nixpkgs.hostPlatform.system}.default;
  hermesHome = "${config.home.homeDirectory}/.hermes";
in
{
  options.modules.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent CLI";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ hermesPackage ];

    home.sessionVariables = {
      HERMES_HOME = hermesHome;
    };
  };
}
