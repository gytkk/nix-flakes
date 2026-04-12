{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  openWebUiPort = 8080;
  tailscaleServePort = 8444;
  tailscaleFqdn = "${config.networking.hostName}.tailbbb9bf.ts.net";
  lanInterface = "wlo1";
  openclawProxyPort = 18790;
  openclawProxyApiKey = "lan-admin-proxy";
  openclawDefaultModel = "openclaw/default";
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
    host = "0.0.0.0";
    port = openWebUiPort;
    environment = {
      # Seed the persistent config on every start so Open WebUI stays declarative.
      ENABLE_PERSISTENT_CONFIG = "true";

      # Seed the admin account so the first authenticated visitor does not
      # become admin by accident.
      WEBUI_ADMIN_EMAIL = "gytk.kim@gmail.com";
      WEBUI_ADMIN_NAME = username;
      ENABLE_SIGNUP = "false";
      DEFAULT_USER_ROLE = "pending";
      ENABLE_LOGIN_FORM = "true";
      ENABLE_PASSWORD_AUTH = "true";
      ENABLE_EVALUATION_ARENA_MODELS = "false";
      ENABLE_OLLAMA_API = "false";
      ENABLE_OPENAI_API = "true";

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
        "http://${config.networking.hostName}:${toString openWebUiPort}"
        "http://${config.networking.hostName}.local:${toString openWebUiPort}"
        "http://192.168.0.10:${toString openWebUiPort}"
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

  networking.firewall.interfaces = {
    "${lanInterface}".allowedTCPPorts = [ openWebUiPort ];
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
      "open-webui.service"
    ];
    wants = [
      "network-online.target"
      "tailscaled.service"
      "open-webui.service"
    ];
    partOf = [
      "tailscaled.service"
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
      wait_for "Open WebUI" curl --fail --silent --show-error "http://127.0.0.1:${toString openWebUiPort}/" >/dev/null

      tailscale serve --yes --bg --https=${toString tailscaleServePort} "127.0.0.1:${toString openWebUiPort}"
      tailscale serve status --json >/dev/null
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --https=${toString tailscaleServePort} off";
    };
  };
}
