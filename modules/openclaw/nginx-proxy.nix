{
  lib,
  common,
  ...
}:
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."openclaw-lan" = {
      serverName = "_";
      listen = [
        {
          addr = "0.0.0.0";
          port = common.lanProxyPort;
        }
      ];
      locations."= /v1/models" = {
        return = ''200 '{"object":"list","data":[{"id":"openclaw/main","object":"model","created":0,"owned_by":"openclaw"},{"id":"openclaw/pro","object":"model","created":0,"owned_by":"openclaw"}]}' '';
        extraConfig = ''
          default_type application/json;
          add_header Content-Type application/json always;
        '';
      };
      locations."/v1/" = {
        proxyPass = "http://127.0.0.1:${toString common.gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          include ${common.gatewayNginxAuthIncludePath};
        '';
      };
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString common.gatewayPort}";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_read_timeout 10m;
          proxy_set_header Host $host:$server_port;
          proxy_set_header X-Forwarded-Host $host:$server_port;
          include ${common.gatewayNginxAuthIncludePath};
        '';
      };
    };
  };

  networking.firewall.interfaces.${common.lanInterface}.allowedTCPPorts = [ common.lanProxyPort ];
}
