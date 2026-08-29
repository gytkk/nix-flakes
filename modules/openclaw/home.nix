{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  cfg = config.modules.openclaw;
  stateDir = toString cfg.stateDir;
  relativeStateDir = lib.removePrefix "${homeDirectory}/" stateDir;
in
{
  options.modules.openclaw = {
    enable = lib.mkEnableOption "runtime integration for a user-managed OpenClaw installation";

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/.openclaw";
      description = "Mutable OpenClaw state and installation directory.";
    };

    agentSessionRecordPlugin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install the repo-managed agent-session-record OpenClaw plugin.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" stateDir;
        message = "modules.openclaw.stateDir must be an absolute path.";
      }
      {
        assertion = !(lib.hasPrefix "/nix/store/" stateDir);
        message = "modules.openclaw.stateDir must point to mutable host storage, not the Nix store.";
      }
      {
        assertion = !cfg.agentSessionRecordPlugin.enable || lib.hasPrefix "${homeDirectory}/" stateDir;
        message = "modules.openclaw.stateDir must be inside the Home Manager home when the agent-session-record plugin is enabled.";
      }
    ];

    home.sessionPath = [ "${stateDir}/bin" ];

    home.file = lib.mkIf cfg.agentSessionRecordPlugin.enable {
      "${relativeStateDir}/extensions/agent-session-record".source =
        ./files/extensions/agent-session-record;
    };

    xdg.configFile."systemd/user/openclaw-gateway.service.d/20-nix-runtime.conf".text = ''
      [Service]
      Environment="PATH=${stateDir}/bin:${stateDir}/tools/node/bin:/run/current-system/sw/bin:${homeDirectory}/.nix-profile/bin:/etc/profiles/per-user/${username}/bin:${homeDirectory}/.local/bin:${homeDirectory}/bin:/usr/local/bin:/usr/bin:/bin"
      Environment="LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.libcap ]}"
    '';

  };
}
