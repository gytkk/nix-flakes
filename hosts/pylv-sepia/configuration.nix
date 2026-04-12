{
  modulesPath,
  pkgs,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
    ./obsidian-headless.nix
    ./obsidian-maintenance
    ../../modules/nixos
  ];

  time.timeZone = "Asia/Seoul";

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # Code Server
  services.code-server = {
    enable = true;
    user = "gytkk";
    host = "0.0.0.0";
    port = 8080;
    auth = "none"; # Tailscale로 접근 제한하므로 인증 불필요
  };

  # Copyparty - file server
  services.copyparty = {
    enable = true;
    settings = {
      i = "0.0.0.0";
      p = [ 3923 ];
    };
    volumes = {
      "/" = {
        path = "/srv/copyparty";
        access = {
          r = "*"; # 모든 사용자 읽기 허용
          w = "*"; # 모든 사용자 쓰기 허용
        };
        flags = {
          e2d = true; # enable file indexing
        };
      };
    };
  };

  # Copyparty 데이터 디렉토리 생성
  systemd.tmpfiles.rules = [
    "d /srv/copyparty 0755 copyparty copyparty -"
  ];

  # Immich - self-hosted photo/video management
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    port = 2283;
  };

  # K3s - lightweight Kubernetes
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--disable=traefik" # Cloudflare Tunnel 사용하므로 비활성화
    ];
  };

  # K3s kubeconfig for non-root users
  environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

  # Fix kubeconfig permissions after k3s starts
  systemd.services.k3s-kubeconfig-permissions = {
    description = "Fix k3s kubeconfig permissions for wheel group";
    after = [ "k3s.service" ];
    requires = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/chmod 644 /etc/rancher/k3s/k3s.yaml";
    };
  };

  # Cloudflare Tunnel (token-based, managed via Zero Trust dashboard)
  age.secrets.cloudflare-tunnel-token = {
    file = ../../secrets/cloudflare-tunnel-token.age;
    owner = "cloudflared";
    group = "cloudflared";
  };

  systemd.services.cloudflared-tunnel = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      ${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run \
        --token "$(cat /run/agenix/cloudflare-tunnel-token)"
    '';
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
      User = "cloudflared";
      Group = "cloudflared";
    };
  };

  users.users.cloudflared = {
    isSystemUser = true;
    group = "cloudflared";
  };
  users.groups.cloudflared = { };

  # Claude Code daily - 매일 오전 6시 (KST) 실행
  systemd.timers.claude-daily = {
    description = "Claude Code Daily Timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 06:00:00";
      Persistent = true;
      Unit = "claude-daily.service";
    };
  };

  systemd.services.claude-daily = {
    description = "Claude Code Daily Hello";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      User = "gytkk";
      Group = "users";
    };
    script = ''
      ${pkgs.claude-code}/bin/claude -p "Hello"
    '';
  };

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    cloudflared
    # Kubernetes tools
    kubectl
    k9s
  ];

  # Firewall - open ports for services
  networking.firewall.allowedTCPPorts = [
    8080 # Code Server
    3923 # Copyparty
    2283 # Immich
  ];

  system.stateVersion = "25.11";
}
