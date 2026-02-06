{
  config,
  lib,
  pkgs,
  ...
}:

{
  # pylv-sepia 환경 전용 설정

  # OpenClaw - enabled with local hasown fix overlay
  # See: https://github.com/openclaw/nix-openclaw/issues/45
  modules.openclaw = {
    enable = true;

    # Discord channel configuration
    discord = {
      enable = true;
      tokenFile = "/run/agenix/discord-bot-token";
      guildId = "1467867949657227318";
      channelId = "1467867998655217850";
    };
  };
}
