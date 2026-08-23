{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  gatewayPort = 18789;
  lanProxyPort = 18790;
  publicProxyPort = 18791;
  lanInterface = "wlo1";
  stateDir = "${homeDirectory}/.openclaw";
  configPath = "${stateDir}/openclaw.json";
  gatewayTokenPath = "${stateDir}/gateway-auth-token";
  nginxAuthPath = "/etc/openclaw/nginx-gateway-auth.conf";
  qmdPackage = pkgs.callPackage ../../packages/qmd/package.nix { };
in
{
  age.secrets.discord-bot-token = {
    file = ../../secrets/discord-bot-token.age;
    owner = username;
    group = "users";
    mode = "0400";
  };

  environment.systemPackages = with pkgs; [
    chromium
    libcap
    qmdPackage
  ];

  environment.sessionVariables = {
    OPENCLAW_CONFIG_PATH = configPath;
    OPENCLAW_STATE_DIR = stateDir;
  };

  system.activationScripts.openclawSyncNginxAuth = lib.stringAfter [ "etc" ] ''
    if [ -L /etc/openclaw ]; then
      ${pkgs.coreutils}/bin/rm /etc/openclaw
    fi
    ${pkgs.coreutils}/bin/mkdir -p /etc/openclaw

    gateway_token=
    if [ -f ${lib.escapeShellArg configPath} ]; then
      gateway_token="$(${pkgs.jq}/bin/jq -er '.gateway.auth.token | select(type == "string") // empty' ${lib.escapeShellArg configPath} 2>/dev/null || true)"
    fi
    if [ -z "$gateway_token" ] && [ -s ${lib.escapeShellArg gatewayTokenPath} ]; then
      gateway_token="$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg gatewayTokenPath})"
    fi

    tmp_auth="$(${pkgs.coreutils}/bin/mktemp)"
    if [ -n "$gateway_token" ]; then
      printf 'proxy_set_header Authorization "Bearer %s";\n' "$gateway_token" > "$tmp_auth"
    else
      printf 'proxy_set_header Authorization "";\n' > "$tmp_auth"
      echo "warning: OpenClaw gateway token is unavailable; proxied requests will not authenticate" >&2
    fi
    ${pkgs.coreutils}/bin/install -m 440 -o root -g ${config.services.nginx.group} "$tmp_auth" ${nginxAuthPath}
    ${pkgs.coreutils}/bin/rm -f "$tmp_auth"
  '';

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
      locations."= /v1/models" = {
        return = ''200 '{"object":"list","data":[{"id":"openclaw/main","object":"model","created":0,"owned_by":"openclaw"},{"id":"openclaw/pro","object":"model","created":0,"owned_by":"openclaw"}]}' '';
        extraConfig = ''
          default_type application/json;
          add_header Content-Type application/json always;
        '';
      };
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          include ${nginxAuthPath};
        '';
      };
    };

    virtualHosts."openclaw-public-origin" = {
      serverName = "_";
      listen = [
        {
          addr = "127.0.0.1";
          port = publicProxyPort;
        }
      ];
      locations."= /v1/models" = {
        return = ''200 '{"object":"list","data":[{"id":"openclaw/main","object":"model","created":0,"owned_by":"openclaw"},{"id":"openclaw/pro","object":"model","created":0,"owned_by":"openclaw"}]}' '';
        extraConfig = ''
          default_type application/json;
          add_header Content-Type application/json always;
        '';
      };
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          include ${nginxAuthPath};
        '';
      };
    };
  };

  networking.firewall.interfaces.${lanInterface}.allowedTCPPorts = [ lanProxyPort ];
}
