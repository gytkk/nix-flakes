{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  isOnyx = config.networking.hostName == "pylv-onyx";
  hermesStateDir = "/var/lib/hermes";
  discordEnvFile = "/var/lib/hermes/discord.env";
  oneHalfLightSkin = pkgs.writeText "hermes-one-half-light.yaml" ''
    name: one-half-light
    description: One Half Light palette aligned with pylv-onyx terminal tooling

    colors:
      banner_border: "#3a9a88"
      banner_title: "#e8862f"
      banner_accent: "#0184bc"
      banner_dim: "#4f525e"
      banner_text: "#383a42"
      ui_accent: "#0184bc"
      ui_label: "#3a9a88"
      ui_ok: "#50a14f"
      ui_error: "#e45649"
      ui_warn: "#c18401"
      prompt: "#383a42"
      input_rule: "#4a9b79"
      response_border: "#e8862f"
      session_label: "#d4a216"
      session_border: "#4f525e"

    spinner:
      thinking_verbs:
        - "indexing context"
        - "tracing symbols"
        - "resolving paths"
        - "shaping changes"
        - "tightening the diff"
      wings:
        - ["‹", "›"]
        - ["⟨", "⟩"]

    branding:
      agent_name: "Hermes Agent"
      welcome: "Welcome to Hermes Agent! Type your message or /help for commands."
      goodbye: "Goodbye."
      response_label: " Hermes "
      prompt_symbol: "❯ "
      help_header: "Available Commands"

    tool_prefix: "│"
  '';
in
{
  config = lib.mkIf isOnyx {
    age.secrets.hermes-discord-bot-token = {
      file = ../../secrets/hermes-discord-bot-token.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.hermes-agent = {
      enable = true;
      user = username;
      group = "users";
      createUser = false;
      addToSystemPackages = true;
      authFile = "${homeDirectory}/.codex/auth.json";
      environmentFiles = [ discordEnvFile ];
      environment = {
        DISCORD_ALLOWED_CHANNELS = "1492848425090285668,1492848439510433833,1492848457348812821,1492848476210331770";
        DISCORD_ALLOWED_USERS = "392300972023611392";
        DISCORD_HOME_CHANNEL = "1492848425090285668";
        DISCORD_HOME_CHANNEL_NAME = "hermes-config";
        DISCORD_REQUIRE_MENTION = "true";
      };
      extraPackages = with pkgs; [
        bun
        curl
        fd
        ffmpeg
        jq
        nodejs
        openssh
        ripgrep
        uv
        wget
      ];
      settings = {
        agent.restart_drain_timeout = 300;
        display = {
          skin = "one-half-light";
          tool_progress = "off";
        };
        model = {
          base_url = "https://chatgpt.com/backend-api/codex";
          default = "gpt-5.4";
          provider = "openai-codex";
        };
        terminal.backend = "local";
      };
    };

    system.activationScripts."hermes-agent-00-discord-env" =
      lib.stringAfter
        ([ "users" ] ++ lib.optional (config.system.activationScripts ? setupSecrets) "setupSecrets")
        ''
          ${pkgs.coreutils}/bin/mkdir -p ${hermesStateDir}
          ${pkgs.coreutils}/bin/chown -R ${username}:users ${hermesStateDir}
          printf 'DISCORD_BOT_TOKEN=%s\n' "$(${pkgs.coreutils}/bin/cat ${config.age.secrets.hermes-discord-bot-token.path})" > ${discordEnvFile}
          ${pkgs.coreutils}/bin/chown root:root ${discordEnvFile}
          ${pkgs.coreutils}/bin/chmod 0600 ${discordEnvFile}
        '';

    system.activationScripts."hermes-agent-10-one-half-light-skin" =
      lib.stringAfter [ "hermes-agent-setup" ] ''
        ${pkgs.coreutils}/bin/install -d -o ${username} -g users -m 0750 \
          ${hermesStateDir}/.hermes/skins
        ${pkgs.coreutils}/bin/install -o ${username} -g users -m 0640 \
          ${oneHalfLightSkin} ${hermesStateDir}/.hermes/skins/one-half-light.yaml
      '';
  };
}
