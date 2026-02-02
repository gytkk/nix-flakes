{
  config,
  lib,
  pkgs,
  inputs,
  homeDirectory,
  ...
}:

let
  cfg = config.modules.openclaw;
  isLinux = pkgs.stdenv.hostPlatform.isLinux;
  isMacOS = pkgs.stdenv.hostPlatform.isDarwin;
in
{
  imports = [
    inputs.nix-openclaw.homeManagerModules.openclaw
  ];

  options.modules.openclaw = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable OpenClaw AI assistant gateway";
    };

    discord = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Discord channel";
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/agenix/discord-bot-token";
        description = "Path to Discord bot token file (agenix secret)";
      };

      guildId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Discord Guild (Server) ID";
      };

      channelId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Discord Channel ID to allow";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Create Discord token env file at activation (before service starts)
    home.activation.openclawDiscordEnv = lib.mkIf (isLinux && cfg.discord.enable) (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p /tmp/openclaw
        if [ -f "${cfg.discord.tokenFile}" ]; then
          echo "DISCORD_BOT_TOKEN=$(cat ${cfg.discord.tokenFile})" > /tmp/openclaw/env
          chmod 600 /tmp/openclaw/env
        else
          # Create empty file to prevent service failure
          touch /tmp/openclaw/env
        fi
      ''
    );

    # Systemd service configuration for Linux
    systemd.user.services.openclaw-gateway = lib.mkIf isLinux {
      Install.WantedBy = [ "default.target" ];

      # Load Discord token from env file (created by activation script)
      Service.EnvironmentFile = lib.mkIf cfg.discord.enable [ "-/tmp/openclaw/env" ];
    };

    programs.openclaw = {
      # Exclude tools that conflict with existing packages
      excludeTools = [
        "nodejs"
        "pnpm"
        "git"
        "curl"
        "jq"
        "ripgrep"
        "ffmpeg"
      ];

      # Don't expose plugin packages to avoid conflicts
      exposePluginPackages = false;

      # Use instances instead of enable to avoid unitName bug
      instances.default = {
        enable = true;

        # Use gateway-only package to avoid npm conflict
        package = pkgs.openclaw-gateway;

        stateDir = "${homeDirectory}/.openclaw";
        workspaceDir = "${homeDirectory}/.openclaw/workspace";

        # Systemd configuration for Linux
        systemd = {
          enable = isLinux;
          unitName = "openclaw-gateway";
        };

        # Launchd configuration for macOS
        launchd = {
          enable = isMacOS;
          label = "com.steipete.openclaw.gateway";
        };

        # Gateway configuration
        config = {
          # Gateway settings
          gateway = {
            mode = "local";
            auth = {
              token = "local-gateway-token";
              mode = "token";
            };
            port = 18789;
            bind = "loopback";
          };

          # Agent defaults
          agents.defaults = {
            workspace = "${homeDirectory}/.openclaw/workspace";
            maxConcurrent = 4;
            subagents.maxConcurrent = 8;
            model.primary = "anthropic/claude-sonnet-4-5";
          };

          # Commands
          commands = {
            native = "auto";
            nativeSkills = "auto";
          };

          # Messages
          messages = {
            ackReactionScope = "group-mentions";
          };

          # Plugins
          plugins.entries.discord.enabled = cfg.discord.enable;

          # Discord channel configuration
          # Token is provided via DISCORD_BOT_TOKEN environment variable (loaded from agenix)
          channels.discord = lib.mkIf cfg.discord.enable {
            enabled = true;
            groupPolicy = "allowlist";

            # DM settings - pairing mode for security
            dm = {
              enabled = true;
              policy = "pairing";
            };

            # Guild configuration
            guilds = lib.mkIf (cfg.discord.guildId != "") {
              "${cfg.discord.guildId}" = {
                requireMention = true;
                channels = lib.mkIf (cfg.discord.channelId != "") {
                  "${cfg.discord.channelId}" = {
                    allow = true;
                    requireMention = true;
                  };
                };
              };
            };
          };

          # Hooks
          hooks.internal = {
            enabled = true;
            entries = {
              session-memory.enabled = true;
              command-logger.enabled = true;
              boot-md.enabled = true;
            };
          };

          # Skills installation
          skills.install.nodeManager = "bun";
        };

        # Plugins disabled for now (unlocked flake reference issue)
        # Enable later: plugins = [ { source = "github:openclaw/nix-steipete-tools?dir=tools/summarize"; } ];
        plugins = [ ];
      };
    };
  };
}
