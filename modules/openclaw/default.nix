{
  config,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  gatewayPort = 18789;
  lanProxyPort = 18790;
  lanInterface = "wlo1";
  stateDir = "${homeDirectory}/.openclaw";
  runtimeConfigPath = "${stateDir}/openclaw.json";
  seedConfigPath = "/etc/openclaw/openclaw.seed.json";
  trustedProxyUser = "lan-admin";
  trustedProxyUserHeader = "x-openclaw-user";
  trustedProxyRequiredHeader = "x-openclaw-proxy";
  trustedProxyRequiredValue = "1";

  seedConfig = {
    gateway = {
      mode = "local";
      auth = {
        mode = "trusted-proxy";
        trustedProxy = {
          userHeader = trustedProxyUserHeader;
          requiredHeaders = [ trustedProxyRequiredHeader ];
          allowUsers = [ trustedProxyUser ];
        };
      };
      port = gatewayPort;
      bind = "loopback";
      trustedProxies = [
        "127.0.0.1"
        "::1"
      ];
      http = {
        endpoints.chatCompletions.enabled = true;
      };
      tailscale.mode = "off";
      controlUi = {
        dangerouslyDisableDeviceAuth = true;
        dangerouslyAllowHostHeaderOriginFallback = true;
      };
    };
  };
in
{
  age.secrets.discord-bot-token = {
    file = ../../secrets/discord-bot-token.age;
    owner = username;
    group = "users";
    mode = "0400";
  };
  services.openclaw-gateway = {
    enable = true;
    package = pkgs.openclaw-gateway;
    port = gatewayPort;
    user = username;
    group = "users";
    createUser = false;
    stateDir = stateDir;
    configPath = seedConfigPath;
    config = seedConfig;

    environment = {
      OPENCLAW_CONFIG_PATH = runtimeConfigPath;
      CLAWDBOT_CONFIG_PATH = runtimeConfigPath;
    };

    execStartPre = [
      "+${pkgs.writeShellScript "openclaw-discord-env" ''
        TOKEN_FILE="/run/agenix/discord-bot-token"
        ENV_DIR="/run/openclaw"
        ENV_FILE="$ENV_DIR/env"
        ${pkgs.coreutils}/bin/mkdir -p "$ENV_DIR"
        if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
          echo "DISCORD_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")" > "$ENV_FILE"
        else
          echo "ERROR: Discord bot token not found or empty at $TOKEN_FILE" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/chmod 600 "$ENV_FILE"
        ${pkgs.coreutils}/bin/chown ${username}:users "$ENV_FILE"
      ''}"
      "${pkgs.writeShellScript "openclaw-runtime-config" ''
        set -euo pipefail

        runtime_config=${pkgs.lib.escapeShellArg runtimeConfigPath}
        seed_config=${pkgs.lib.escapeShellArg seedConfigPath}
        state_dir=${pkgs.lib.escapeShellArg stateDir}

        mkdir -p "$state_dir"

        if [ -L "$runtime_config" ]; then
          migrated_file="$(${pkgs.coreutils}/bin/mktemp "$state_dir/openclaw.json.migrate.XXXXXX")"
          ${pkgs.coreutils}/bin/cp --dereference "$runtime_config" "$migrated_file"
          ${pkgs.coreutils}/bin/chmod 600 "$migrated_file"
          ${pkgs.coreutils}/bin/mv -f "$migrated_file" "$runtime_config"
        fi

        if [ ! -e "$runtime_config" ]; then
          seeded_file="$(${pkgs.coreutils}/bin/mktemp "$state_dir/openclaw.json.seed.XXXXXX")"
          ${pkgs.coreutils}/bin/cp "$seed_config" "$seeded_file"
          ${pkgs.coreutils}/bin/chmod 600 "$seeded_file"
          ${pkgs.coreutils}/bin/mv -f "$seeded_file" "$runtime_config"
        fi

        ${pkgs.jq}/bin/jq -e . "$runtime_config" >/dev/null
      ''}"
    ];
    environmentFiles = [ "-/run/openclaw/env" ];

    servicePath = with pkgs; [
      bun
      nodejs
    ];
  };

  environment.systemPackages = [ pkgs.openclaw-gateway ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."openclaw-lan" = {
      serverName = "_";
      listen = [
        {
          addr = "0.0.0.0";
          port = lanProxyPort;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          proxy_set_header ${trustedProxyUserHeader} ${trustedProxyUser};
          proxy_set_header ${trustedProxyRequiredHeader} ${trustedProxyRequiredValue};
        '';
      };
    };
  };

  networking.firewall.interfaces = {
    "${lanInterface}".allowedTCPPorts = [ lanProxyPort ];
  };
}
