{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  openWebUiFrontendPort = 8080;
  openWebUiBackendPort = 8081;
  tailscaleServePort = 8444;
  tailscaleFqdn = "${config.networking.hostName}.tailbbb9bf.ts.net";
  lanInterface = "wlo1";
  openclawProxyPort = 18790;
  openclawProxyApiKey = "lan-admin-proxy";
  openclawDefaultModel = "openclaw/default";
  openWebUiTrustedEmail = "gytk.kim@gmail.com";
  openWebUiTrustedEmailHeader = "x-open-webui-email";
  openWebUiTrustedNameHeader = "x-open-webui-name";
  openWebUiDataDir = "${config.services.open-webui.stateDir}/data";
  openWebUiSeedConfig = builtins.toJSON {
    version = 0;
    ui = { };
    openai.api_configs = {
      "0" = {
        enable = true;
        model_ids = [ openclawDefaultModel ];
      };
    };
  };
in
{
  age.secrets.open-webui-env = {
    file = ../../secrets/open-webui-env.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = openWebUiBackendPort;
    environment = {
      # Seed the persistent config on every start so Open WebUI stays declarative.
      ENABLE_PERSISTENT_CONFIG = "true";

      # Seed the admin account so the first authenticated visitor does not
      # become admin by accident.
      WEBUI_ADMIN_EMAIL = openWebUiTrustedEmail;
      WEBUI_ADMIN_NAME = username;
      ENABLE_SIGNUP = "false";
      DEFAULT_USER_ROLE = "pending";
      ENABLE_LOGIN_FORM = "false";
      ENABLE_PASSWORD_AUTH = "true";
      ENABLE_EVALUATION_ARENA_MODELS = "false";
      ENABLE_OLLAMA_API = "false";
      ENABLE_OPENAI_API = "true";
      WEBUI_AUTH_TRUSTED_EMAIL_HEADER = openWebUiTrustedEmailHeader;
      WEBUI_AUTH_TRUSTED_NAME_HEADER = openWebUiTrustedNameHeader;

      # Route all OpenAI-compatible traffic through the local trusted proxy.
      OPENAI_API_BASE_URL = "http://127.0.0.1:${toString openclawProxyPort}/v1";
      OPENAI_API_KEY = openclawProxyApiKey;
      OPENAI_API_BASE_URLS = "http://127.0.0.1:${toString openclawProxyPort}/v1";
      OPENAI_API_KEYS = openclawProxyApiKey;
      DEFAULT_MODELS = openclawDefaultModel;
      TASK_MODEL_EXTERNAL = openclawDefaultModel;
      FORWARDED_ALLOW_IPS = "127.0.0.1,::1";

      # The app is reachable through Tailscale, the LAN, or a local SSH tunnel.
      CORS_ALLOW_ORIGIN = lib.concatStringsSep ";" [
        "https://${tailscaleFqdn}:${toString tailscaleServePort}"
        "http://${config.networking.hostName}:${toString openWebUiFrontendPort}"
        "http://${config.networking.hostName}.local:${toString openWebUiFrontendPort}"
        "http://192.168.0.10:${toString openWebUiFrontendPort}"
        "http://localhost:3000"
        "http://127.0.0.1:3000"
      ];
      WEBUI_SESSION_COOKIE_SAME_SITE = "strict";
      XFRAME_OPTIONS = "DENY";
      XCONTENT_TYPE = "nosniff";
      REFERRER_POLICY = "strict-origin-when-cross-origin";
      PERMISSIONS_POLICY = "camera=(),microphone=(),geolocation=()";
    };
    environmentFile = config.age.secrets.open-webui-env.path;
  };

  services.nginx.virtualHosts."open-webui-lan" = {
    serverName = "_";
    listen = [
      {
        addr = "0.0.0.0";
        port = openWebUiFrontendPort;
      }
    ];
    locations."/ws/socket.io/" = {
      proxyPass = "http://127.0.0.1:${toString openWebUiBackendPort}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_set_header ${openWebUiTrustedEmailHeader} ${openWebUiTrustedEmail};
        proxy_set_header ${openWebUiTrustedNameHeader} ${username};
      '';
    };
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString openWebUiBackendPort}";
      extraConfig = ''
        proxy_set_header ${openWebUiTrustedEmailHeader} ${openWebUiTrustedEmail};
        proxy_set_header ${openWebUiTrustedNameHeader} ${username};
      '';
    };
  };

  networking.firewall.interfaces = {
    "${lanInterface}".allowedTCPPorts = [ openWebUiFrontendPort ];
  };

  systemd.services.open-webui.preStart = lib.mkForce ''
    mkdir -p "${openWebUiDataDir}"

    [ -f "${config.services.open-webui.stateDir}/webui.db" ] && mv "${config.services.open-webui.stateDir}/webui.db" "${openWebUiDataDir}/"

    for dir in cache uploads vector_db; do
      [ -d "${config.services.open-webui.stateDir}/$dir" ] && mv "${config.services.open-webui.stateDir}/$dir" "${openWebUiDataDir}/"
    done

    printf '%s\n' ${lib.escapeShellArg openWebUiSeedConfig} > "${openWebUiDataDir}/config.json"
  '';

  systemd.services.tailscale-serve-open-webui = {
    description = "Expose Open WebUI through Tailscale Serve";
    after = [
      "network-online.target"
      "tailscaled.service"
      "nginx.service"
      "open-webui.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "nginx.service"
      "open-webui.service"
    ];
    partOf = [
      "tailscaled.service"
      "nginx.service"
      "open-webui.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      curl
      tailscale
    ];
    script = ''
      wait_for() {
        local name="$1"
        shift

        for _ in $(seq 1 60); do
          if "$@"; then
            return 0
          fi

          sleep 1
        done

        echo "ERROR: $name did not become ready in time" >&2
        return 1
      }

      wait_for "tailscaled" tailscale status --json >/dev/null 2>&1
      wait_for "Open WebUI frontend" curl --fail --silent --show-error "http://127.0.0.1:${toString openWebUiFrontendPort}/" >/dev/null

      tailscale serve --yes --bg --https=${toString tailscaleServePort} "127.0.0.1:${toString openWebUiFrontendPort}"
      tailscale serve status --json >/dev/null
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --https=${toString tailscaleServePort} off";
    };
  };
}
