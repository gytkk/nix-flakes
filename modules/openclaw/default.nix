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
  };

  config = lib.mkIf cfg.enable {
    # Add Install section for systemd auto-start on Linux
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
          enable = true;
          unitName = "openclaw-gateway";
        };

        # Launchd configuration for macOS
        launchd = {
          enable = true;
          label = "com.steipete.openclaw.gateway";
        };

        # Minimal configuration - customize as needed
        config = {
          gateway = {
            mode = "local";
            auth = {
              # Set via environment variable OPENCLAW_GATEWAY_TOKEN
              token = "placeholder";
            };
          };

          # Configure your channels (Telegram, Discord, etc.)
          # channels.telegram = {
          #   tokenFile = "/path/to/telegram-bot-token";
          #   allowFrom = [ YOUR_TELEGRAM_USER_ID ];
          # };
        };

        # Add plugins as needed
        # plugins = [
        #   { source = "github:openclaw/nix-steipete-tools?dir=tools/summarize"; }
        # ];
      };
    };
  };
}
