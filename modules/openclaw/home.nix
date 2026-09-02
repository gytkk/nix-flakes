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
  gatewayWrapper = pkgs.writeShellApplication {
    name = "openclaw-gateway-with-secrets";
    text = ''
      exec ${pkgs.bash}/bin/bash ${./files/gateway-wrapper.sh} \
        ${lib.escapeShellArg "${stateDir}/bin/openclaw"} \
        ${lib.escapeShellArg cfg.discordBotTokenFile} \
        "$@"
    '';
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

    gatewayPort = lib.mkOption {
      type = lib.types.port;
      default = 18789;
      description = "Loopback port passed to the OpenClaw-managed Gateway service.";
    };

    discordBotTokenFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/agenix/discord-bot-token";
      description = "Raw Discord bot token file exported only to the Gateway process and its command jobs.";
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
      {
        assertion = lib.hasPrefix "/" cfg.discordBotTokenFile;
        message = "modules.openclaw.discordBotTokenFile must be an absolute path.";
      }
      {
        assertion = !(lib.hasPrefix "/nix/store/" cfg.discordBotTokenFile);
        message = "modules.openclaw.discordBotTokenFile must not place a secret in the Nix store.";
      }
    ];

    home.sessionPath = [ "${stateDir}/bin" ];

    home.packages = [ gatewayWrapper ];

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
      ExecStart=
      ExecStart=${gatewayWrapper}/bin/openclaw-gateway-with-secrets gateway --port ${toString cfg.gatewayPort}
      Environment="OPENCLAW_WRAPPER=${gatewayWrapper}/bin/openclaw-gateway-with-secrets"
      Environment="LD_LIBRARY_PATH=${lib.makeLibraryPath [ pkgs.libcap ]}"
      ${lib.optionalString cfg.agentCore.enable ''Environment="AGENT_CORE_OPENCLAW_INSTRUCTIONS=${homeDirectory}/${agentCoreDir}/AGENTS.core.md"''}
    '';

  };
}
