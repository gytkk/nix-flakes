{
  modulesPath,
  pkgs,
  ...
}@args:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disk-config.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  # Services
  services.openssh.enable = true;
  services.tailscale.enable = true;

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
    # mediaLocation = "/var/lib/immich"; # 기본값 사용
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
  # Allow wheel group to read kubeconfig
  systemd.tmpfiles.settings."k3s-kubeconfig" = {
    "/etc/rancher/k3s/k3s.yaml".z = {
      mode = "0640";
      user = "root";
      group = "wheel";
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
    after = [
      "network-online.target"
      "agenix.service"
    ];
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

  # Minimal system packages (most packages managed by Home Manager)
  environment.systemPackages = with pkgs; [
    cloudflared
    curl
    dnsutils
    wget
    vim
    # Kubernetes tools
    kubectl
    k9s
  ];

  # Enable zsh system-wide (configuration via Home Manager)
  programs.zsh.enable = true;

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Firewall - open ports for services
  networking.firewall.allowedTCPPorts = [
    8080  # Code Server
    3923  # Copyparty
    2283  # Immich
  ];

  # Security
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Users
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio gytk.kim@gmail.com"
  ] ++ (args.extraPublicKeys or [ ]);

  users.users.gytkk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio gytk.kim@gmail.com"
    ];
  };

  system.stateVersion = "25.11";
}
