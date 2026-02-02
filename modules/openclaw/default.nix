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
    # Systemd service configuration for Linux
    systemd.user.services.openclaw-gateway = lib.mkIf isLinux {
      Install.WantedBy = [ "default.target" ];
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
          channels.discord = lib.mkIf cfg.discord.enable {
            enabled = true;
            tokenFile = cfg.discord.tokenFile;
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

        # Plugins - summarize for basic functionality
        plugins = [
          { source = "github:openclaw/nix-steipete-tools?dir=tools/summarize"; }
        ];
      };
    };
  };
}
