{
  config,
  lib,
  pkgs,
  username,
  ...
}:
let
  openWebUiFrontendPort = 8787;
  openWebUiBackendPort = 8788;
  hermesApiPort = 8642;
  hermesApiModelName = "hermes-agent";
  tailscaleServePort = 8445;
  publicFqdn = "openwebui.pylv.dev";
  tailscaleFqdn = "${config.networking.hostName}.tailbbb9bf.ts.net";
  cloudflareTunnelTokenFile = ../../secrets/cloudflare-tunnel-onyx-token.age;
  cloudflareTunnelEnabled = builtins.pathExists cloudflareTunnelTokenFile;
  openWebUiStateDir = "/var/lib/hermes-open-webui";
  openWebUiRuntimeEnvFile = "/run/hermes-open-webui.env";
  openWebUiDataDir = "${openWebUiStateDir}/data";
  hermesEnvFile = "/var/lib/hermes/.hermes/.env";
  hermesApiBaseUrl = "http://127.0.0.1:${toString hermesApiPort}/v1";
  openWebUiSeedConfig = builtins.toJSON {
    version = 0;
    ui = { };
    openai.api_configs = {
      "0" = {
        enable = true;
        model_ids = [ hermesApiModelName ];
      };
    };
  };
  proxyPassTarget = "http://127.0.0.1:${toString openWebUiBackendPort}";
  proxyHeaders = ''
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Real-Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
  '';
in
{
  age.secrets.hermes-webui-env = {
    file = ../../secrets/hermes-webui-env.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  age.secrets.cloudflare-tunnel-onyx-token = lib.mkIf cloudflareTunnelEnabled {
    file = cloudflareTunnelTokenFile;
    owner = "cloudflared";
    group = "cloudflared";
  };

  users.users.cloudflared = lib.mkIf cloudflareTunnelEnabled {
    isSystemUser = true;
    group = "cloudflared";
  };

  users.groups.cloudflared = lib.mkIf cloudflareTunnelEnabled { };

  users.users.open-webui = {
    isSystemUser = true;
    group = "open-webui";
  };

  users.groups.open-webui = { };

  environment.systemPackages = lib.mkIf cloudflareTunnelEnabled [ pkgs.cloudflared ];

  systemd.services.hermes-open-webui-env = {
    description = "Generate Hermes Open WebUI runtime environment";
    before = [ "open-webui.service" ];
    requiredBy = [ "open-webui.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      set -euo pipefail

      . ${config.age.secrets.hermes-webui-env.path}

      if [ -z "''${HERMES_WEBUI_PASSWORD:-}" ]; then
        echo "ERROR: HERMES_WEBUI_PASSWORD is missing from ${config.age.secrets.hermes-webui-env.path}" >&2
        exit 1
      fi

      ${pkgs.coreutils}/bin/install -D -m 0600 /dev/null ${lib.escapeShellArg openWebUiRuntimeEnvFile}
      cat > ${lib.escapeShellArg openWebUiRuntimeEnvFile} <<EOF
WEBUI_ADMIN_PASSWORD=''${HERMES_WEBUI_PASSWORD}
WEBUI_SECRET_KEY=''${HERMES_WEBUI_PASSWORD}
OPENAI_API_KEY=''${HERMES_WEBUI_PASSWORD}
OPENAI_API_KEYS=''${HERMES_WEBUI_PASSWORD}
EOF
    '';
  };

  systemd.services.hermes-agent.preStart = lib.mkAfter ''
    HERMES_ENV_FILE=${lib.escapeShellArg hermesEnvFile}

    . ${config.age.secrets.hermes-webui-env.path}

    if [ -z "''${HERMES_WEBUI_PASSWORD:-}" ]; then
      echo "ERROR: HERMES_WEBUI_PASSWORD is missing from ${config.age.secrets.hermes-webui-env.path}" >&2
      exit 1
    fi

    mkdir -p "$(dirname "$HERMES_ENV_FILE")"
    touch "$HERMES_ENV_FILE"
    chmod 0640 "$HERMES_ENV_FILE"

    ${pkgs.gnused}/bin/sed -i \
      -e '/^API_SERVER_ENABLED=/d' \
      -e '/^API_SERVER_HOST=/d' \
      -e '/^API_SERVER_PORT=/d' \
      -e '/^API_SERVER_MODEL_NAME=/d' \
      -e '/^API_SERVER_KEY=/d' \
      "$HERMES_ENV_FILE"

    cat >> "$HERMES_ENV_FILE" <<EOF
API_SERVER_ENABLED=true
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=${toString hermesApiPort}
API_SERVER_MODEL_NAME=${hermesApiModelName}
API_SERVER_KEY=''${HERMES_WEBUI_PASSWORD}
EOF
    chmod 0640 "$HERMES_ENV_FILE"
  '';

  services.open-webui = {
    enable = true;
    stateDir = openWebUiStateDir;
    host = "127.0.0.1";
    port = openWebUiBackendPort;
    environment = {
      ENABLE_PERSISTENT_CONFIG = "true";
      WEBUI_ADMIN_EMAIL = "gytk.kim@gmail.com";
      WEBUI_ADMIN_NAME = username;
      ENABLE_SIGNUP = "false";
      DEFAULT_USER_ROLE = "pending";
      ENABLE_LOGIN_FORM = "true";
      ENABLE_PASSWORD_AUTH = "true";
      ENABLE_EVALUATION_ARENA_MODELS = "false";
      ENABLE_OLLAMA_API = "false";
      ENABLE_OPENAI_API = "true";
      OPENAI_API_BASE_URL = hermesApiBaseUrl;
      OPENAI_API_BASE_URLS = hermesApiBaseUrl;
      DEFAULT_MODELS = hermesApiModelName;
      TASK_MODEL_EXTERNAL = hermesApiModelName;
      FORWARDED_ALLOW_IPS = "127.0.0.1,::1";
      CORS_ALLOW_ORIGIN = lib.concatStringsSep ";" [
        "https://${publicFqdn}"
        "https://${tailscaleFqdn}:${toString tailscaleServePort}"
        "http://localhost:3000"
        "http://127.0.0.1:3000"
      ];
      WEBUI_SESSION_COOKIE_SAME_SITE = "strict";
      XFRAME_OPTIONS = "DENY";
      XCONTENT_TYPE = "nosniff";
      REFERRER_POLICY = "strict-origin-when-cross-origin";
      PERMISSIONS_POLICY = "camera=(),microphone=(),geolocation=()";
    };
    environmentFile = openWebUiRuntimeEnvFile;
  };

  systemd.services.open-webui = {
    after = [
      "hermes-agent.service"
      "hermes-open-webui-env.service"
    ];
    wants = [
      "hermes-agent.service"
      "hermes-open-webui-env.service"
    ];
    preStart = lib.mkForce ''
      mkdir -p "${openWebUiDataDir}"

      [ -f "${openWebUiStateDir}/webui.db" ] && mv "${openWebUiStateDir}/webui.db" "${openWebUiDataDir}/"

      for dir in cache uploads vector_db; do
        [ -d "${openWebUiStateDir}/$dir" ] && mv "${openWebUiStateDir}/$dir" "${openWebUiDataDir}/"
      done

      printf '%s\n' ${lib.escapeShellArg openWebUiSeedConfig} > "${openWebUiDataDir}/config.json"
    '';
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = lib.mkForce "open-webui";
      Group = lib.mkForce "open-webui";
      StateDirectory = lib.mkForce "hermes-open-webui";
      RuntimeDirectory = lib.mkForce "hermes-open-webui";
      RuntimeDirectoryMode = lib.mkForce "0750";
      WorkingDirectory = lib.mkForce openWebUiStateDir;
    };
  };

  services.nginx.virtualHosts."hermes-open-webui-origin" = {
    serverName = "_";
    listen = [
      {
        addr = "127.0.0.1";
        port = openWebUiFrontendPort;
      }
    ];
    locations."/ws/socket.io/" = {
      proxyPass = proxyPassTarget;
      proxyWebsockets = true;
      extraConfig = ''
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 1h;
        ${proxyHeaders}
      '';
    };
    locations."/" = {
      proxyPass = proxyPassTarget;
      extraConfig = ''
        client_max_body_size 25m;
        proxy_buffering off;
        proxy_read_timeout 1h;
        ${proxyHeaders}
      '';
    };
  };

  systemd.services.cloudflared-tunnel-hermes-open-webui = lib.mkIf cloudflareTunnelEnabled {
    description = "Cloudflare Tunnel for Hermes Open WebUI";
    after = [
      "network-online.target"
      "nginx.service"
      "open-webui.service"
    ];
    wants = [
      "network-online.target"
      "nginx.service"
      "open-webui.service"
    ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run \
        --token "$(cat ${config.age.secrets.cloudflare-tunnel-onyx-token.path})"
    '';
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
      User = "cloudflared";
      Group = "cloudflared";
    };
  };

  systemd.services.tailscale-serve-hermes-open-webui = {
    description = "Expose Hermes Open WebUI through Tailscale Serve";
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
      wait_for "Hermes Open WebUI frontend" curl --fail --silent --show-error "http://127.0.0.1:${toString openWebUiFrontendPort}/" >/dev/null

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
