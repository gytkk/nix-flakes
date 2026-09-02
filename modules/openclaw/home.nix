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
  agentCoreDir = ".local/share/openclaw/agent-core";
  extensionsDir = ".local/share/openclaw/extensions";
  agentCoreOutput = import ../../agent-core/nix/render.nix { inherit pkgs; } {
    runtime = "openclaw";
  };
in
{
  options.modules.openclaw = {
    enable = lib.mkEnableOption "runtime integration for a user-managed OpenClaw installation";

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "${homeDirectory}/.openclaw";
      description = "Mutable OpenClaw state and installation directory.";
    };

    agentCore.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install shared agent-core instructions, skills, and prompt hook.";
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
    ];

    home.sessionPath = [ "${stateDir}/bin" ];

    home.file = lib.mkMerge [
      (lib.mkIf cfg.agentCore.enable {
        "${agentCoreDir}/AGENTS.core.md".source = "${agentCoreOutput}/AGENTS.core.md";
        "${agentCoreDir}/skills".source = "${agentCoreOutput}/skills";
        "${extensionsDir}/agent-core-context".source = ./files/extensions/agent-core-context;
      })
      (lib.mkIf cfg.agentSessionRecordPlugin.enable {
        "${extensionsDir}/agent-session-record".source = ./files/extensions/agent-session-record;
      })
    ];

    xdg.configFile."systemd/user/openclaw-gateway.service.d/20-nix-runtime.conf".text = ''
      [Service]
      Environment="LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.libcap ]}"
      ${lib.optionalString cfg.agentCore.enable ''Environment="AGENT_CORE_OPENCLAW_INSTRUCTIONS=${homeDirectory}/${agentCoreDir}/AGENTS.core.md"''}
    '';

  };
}
