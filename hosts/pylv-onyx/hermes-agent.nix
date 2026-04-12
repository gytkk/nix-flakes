{
  pkgs,
  inputs,
  username,
  homeDirectory,
  ...
}:
let
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  stateDir = "${homeDirectory}/.hermes-service";
  hermesHome = "${stateDir}/.hermes";
  workingDirectory = "${stateDir}/workspace";
in
{
  age.secrets.hermes-discord-bot-token = {
    file = ../../secrets/hermes-discord-bot-token.age;
    owner = username;
    group = "users";
    mode = "0400";
  };

  services.hermes-agent = {
    enable = true;
    package = hermesPackage;

    # Run as the main user, similar to the current OpenClaw setup.
    user = username;
    group = "users";
    createUser = false;

    # Keep service-managed runtime state separate from the user's personal
    # ~/.hermes CLI sandbox, while still living under the home directory.
    stateDir = stateDir;
    workingDirectory = workingDirectory;

    # Install the CLI system-wide too, so `hermes` is available even outside
    # Home Manager contexts. We intentionally do NOT force shared HERMES_HOME
    # in shells; use the helper alias when you want to inspect service state.
    addToSystemPackages = false;

    # Only manage a few baseline settings declaratively. User-added settings in
    # config.yaml are preserved by the upstream deep-merge activation logic.
    settings = {
      terminal.backend = "local";
      display.tool_progress = "off";
    };

    environment = {
      DISCORD_ALLOWED_USERS = "392300972023611392";
      DISCORD_HOME_CHANNEL = "1492784291049115760";
      DISCORD_HOME_CHANNEL_NAME = "#claw-dev";
      DISCORD_REQUIRE_MENTION = "true";
    };

    extraPackages = with pkgs; [
      git
      nodejs
      bun
      uv
      ripgrep
      fd
      jq
      wget
      curl
      ffmpeg
    ];
  };

  systemd.services.hermes-agent.preStart = ''
    TOKEN_FILE="/run/agenix/hermes-discord-bot-token"
    HERMES_ENV_FILE="${stateDir}/.hermes/.env"

    if [ ! -f "$TOKEN_FILE" ] || [ ! -s "$TOKEN_FILE" ]; then
      echo "ERROR: Hermes Discord bot token not found or empty at $TOKEN_FILE" >&2
      exit 1
    fi

    mkdir -p "$(dirname "$HERMES_ENV_FILE")"
    touch "$HERMES_ENV_FILE"

    ${pkgs.gnused}/bin/sed -i '/^DISCORD_BOT_TOKEN=/d' "$HERMES_ENV_FILE"
    printf 'DISCORD_BOT_TOKEN=%s\n' "$(cat "$TOKEN_FILE")" >> "$HERMES_ENV_FILE"
    chown ${username}:users "$HERMES_ENV_FILE"
    chmod 640 "$HERMES_ENV_FILE"
  '';

  environment.systemPackages = [ hermesPackage ];

  environment.sessionVariables = {
    HERMES_SERVICE_STATE_DIR = stateDir;
    HERMES_SERVICE_HOME = hermesHome;
  };
}
