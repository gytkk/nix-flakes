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
    port = openWebUiPort;
    environment = {
      # Keep security-sensitive settings declarative instead of UI-persisted.
      ENABLE_PERSISTENT_CONFIG = "false";

      # Seed the admin account so the first authenticated visitor does not
      # become admin by accident.
      WEBUI_ADMIN_EMAIL = "gytk.kim@gmail.com";
      WEBUI_ADMIN_NAME = username;
      ENABLE_SIGNUP = "false";
      DEFAULT_USER_ROLE = "pending";
      ENABLE_LOGIN_FORM = "true";
      ENABLE_PASSWORD_AUTH = "true";

      # Tailscale Serve injects these headers; localhost access still uses the
      # standard login form over an SSH tunnel.
      WEBUI_AUTH_TRUSTED_EMAIL_HEADER = "Tailscale-User-Login";
      WEBUI_AUTH_TRUSTED_NAME_HEADER = "Tailscale-User-Name";
      FORWARDED_ALLOW_IPS = "127.0.0.1,::1";

      # The app is reachable only through the Tailscale URL or a local SSH tunnel.
      CORS_ALLOW_ORIGIN = lib.concatStringsSep ";" [
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
    environmentFile = config.age.secrets.open-webui-env.path;
  };

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
