{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.gksdud;
  appPath = "${config.home.homeDirectory}/Applications/gksdud.app";
in
{
  options.modules.gksdud.enable = lib.mkEnableOption "gksdud Korean and English input switching";

  config = lib.mkIf (cfg.enable && pkgs.stdenv.isDarwin) {
    home.packages = [ pkgs.gksdud ];
    home.file."Applications/gksdud.app".source = "${pkgs.gksdud}/Applications/gksdud.app";

    # Write individual keys to preserve gksdud's keyboard records and restoration data.
    home.activation.gksdudSettings =
      lib.hm.dag.entryBetween
        [ "setupLaunchAgents" ]
        [
          "writeBoundary"
          "linkGeneration"
        ]
        ''
          run /usr/bin/defaults write io.gksdud.inputswitch source -string 30064771303
          run /usr/bin/defaults write io.gksdud.inputswitch target -string F19
          run /usr/bin/defaults write io.gksdud.inputswitch active -bool true
          run /usr/bin/defaults write io.gksdud.inputswitch switchOnKeyDown -bool true
        '';

    launchd.agents.gksdud = {
      enable = true;
      config = {
        ProgramArguments = [
          "/usr/bin/open"
          "-a"
          appPath
        ];
        RunAtLoad = true;
        ProcessType = "Interactive";
      };
    };
  };
}
