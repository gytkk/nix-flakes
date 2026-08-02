{
  config,
  pkgs,
  username,
  homeDirectory,
  ...
}:
let
  dashboardFqdn = "hermes.pylv.dev";
  dashboardPort = 9119;
  dashboardOriginPort = 19119;
  hermesHome = "${homeDirectory}/.hermes";
  hermesBin = "${homeDirectory}/.local/bin/hermes";
in
{
  age.secrets.cloudflare-tunnel-onyx-token = {
    file = ../../secrets/cloudflare-tunnel-onyx-token.age;
    owner = "cloudflared";
    group = "cloudflared";
  };

  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };
  users.groups.cloudflared = { };

  environment.systemPackages = [ pkgs.cloudflared ];

  systemd.services.hermes-dashboard = {
    description = "Hermes Agent web dashboard";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      "${homeDirectory}/.local"
      "${homeDirectory}/.nix-profile"
      "/etc/profiles/per-user/${username}"
      "/run/current-system/sw"
    ];
    environment = {
      HOME = homeDirectory;
      HERMES_HOME = hermesHome;
      SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
    };
    serviceConfig = {
      Type = "simple";
      User = username;
      Group = "users";
      WorkingDirectory = hermesHome;
      ExecStart = ''
        ${hermesBin} dashboard \
          --host 127.0.0.1 \
          --port ${toString dashboardPort} \
          --no-open
      '';
      Restart = "always";
      RestartSec = 5;
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadOnlyPaths = [ "${homeDirectory}/.local" ];
      ReadWritePaths = [ hermesHome ];
    };
  };

  services.nginx.virtualHosts."hermes-dashboard-origin" = {
    serverName = dashboardFqdn;
    listen = [
      {
        addr = "127.0.0.1";
        port = dashboardOriginPort;
      }
    ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString dashboardPort}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 10m;
        proxy_set_header Host 127.0.0.1:${toString dashboardPort};
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Proto https;
      '';
    };
  };

  systemd.services.cloudflared-tunnel-hermes-dashboard = {
    description = "Cloudflare Tunnel for Hermes Dashboard";
    after = [
      "network-online.target"
      "nginx.service"
      "hermes-dashboard.service"
    ];
    wants = [
      "network-online.target"
      "nginx.service"
      "hermes-dashboard.service"
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
}
