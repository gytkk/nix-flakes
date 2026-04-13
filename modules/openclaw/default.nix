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

  environment.etc."openclaw/openclaw.seed.json".text = builtins.toJSON seedConfig;

  environment.etc."profile.d/openclaw-discord-token.sh".text = ''
    if [ -z "''${DISCORD_BOT_TOKEN-}" ] && [ -r /run/agenix/discord-bot-token ]; then
      export DISCORD_BOT_TOKEN="$(cat /run/agenix/discord-bot-token)"
    fi
  '';

  environment.systemPackages = with pkgs; [
    openclaw-gateway
    bun
    nodejs
  ];

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
