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
  services.openssh = {
    enable = true;
    # Ghostty ssh-env가 전달하는 터미널 환경 변수 수락 (Claude Code TUI 렌더링에 필요)
    extraConfig = ''
      AcceptEnv COLORTERM TERM_PROGRAM TERM_PROGRAM_VERSION
    '';
  };
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

  # /bin/bash shebang 호환성 (서드파티 스크립트용)
  system.activationScripts.binbash = ''
    ln -sfn ${pkgs.bash}/bin/bash /bin/bash
  '';

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

  # Discord bot token for openclaw (readable by openclaw system user)
  age.secrets.discord-bot-token = {
    file = ../../secrets/discord-bot-token.age;
    owner = "openclaw";
    group = "openclaw";
    mode = "0400";
  };

  # OpenClaw Gateway - NixOS system service
  services.openclaw-gateway =
    let
      gatewayPort = 18789;
    in
    {
      enable = true;
      package = pkgs.openclaw-gateway;
      port = gatewayPort;
      stateDir = "/var/lib/openclaw";

      # Convert raw agenix token to KEY=VALUE format (runs as root via + prefix)
      # Fail-closed: service won't start if Discord token is missing
      execStartPre = [
        "+${pkgs.writeShellScript "openclaw-discord-env" ''
          TOKEN_FILE="/run/agenix/discord-bot-token"
          ENV_DIR="/run/openclaw"
          ENV_FILE="$ENV_DIR/env"
          ${pkgs.coreutils}/bin/mkdir -p "$ENV_DIR"
          if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
            echo "DISCORD_BOT_TOKEN=$(${pkgs.coreutils}/bin/cat "$TOKEN_FILE")" > "$ENV_FILE"
          else
            echo "ERROR: Discord bot token not found or empty at $TOKEN_FILE" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/chmod 600 "$ENV_FILE"
          ${pkgs.coreutils}/bin/chown openclaw:openclaw "$ENV_FILE"
        ''}"
      ];
      environmentFiles = [ "-/run/openclaw/env" ];

      servicePath = with pkgs; [
        bun
        nodejs
      ];

      config = {
        gateway = {
          mode = "local";
          auth = {
            # Loopback-only token: not externally reachable (bind = "loopback" + Tailscale serve)
            token = "local-gateway-token";
            mode = "token";
          };
          port = gatewayPort;
          bind = "loopback";
          trustedProxies = [
            "127.0.0.1"
            "::1"
          ];
          tailscale.mode = "serve";
          controlUi.dangerouslyDisableDeviceAuth = true;
        };

        agents = {
          defaults = {
            workspace = "/var/lib/openclaw/workspace";
            maxConcurrent = 4;
            subagents.maxConcurrent = 8;
            model.primary = "openai/gpt-5.4";
            thinkingDefault = "xhigh";
          };
          list = [
            {
              id = "main";
              default = true;
              name = "Main";
              model.primary = "openai/gpt-5.4";
            }
            {
              id = "gpt-pro";
              name = "GPT Pro";
              model.primary = "openai/gpt-5.4-pro";
            }
            {
              id = "sonnet";
              name = "Sonnet";
              model.primary = "anthropic/claude-sonnet-4-6";
            }
            {
              id = "opus";
              name = "Opus";
              model.primary = "anthropic/claude-opus-4-6";
            }
          ];
        };

        commands = {
          native = "auto";
          nativeSkills = "auto";
        };

        messages.ackReactionScope = "group-mentions";

        plugins.entries.discord.enabled = true;

        channels.discord = {
          enabled = true;
          groupPolicy = "allowlist";
          dm = {
            enabled = true;
            policy = "pairing";
          };
          guilds."1467867949657227318" = {
            requireMention = true;
            channels."1467867998655217850" = {
              allow = true;
              requireMention = true;
            };
          };
        };

        hooks.internal = {
          enabled = true;
          entries = {
            session-memory.enabled = true;
            command-logger.enabled = true;
            boot-md.enabled = true;
          };
        };

        # Explicit model registration (for models not yet in the built-in catalog)
        models.providers = {
          openai = {
            models = [
              {
                id = "gpt-5.4";
                name = "GPT 5.4";
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 1048576;
              }
              {
                id = "gpt-5.4-pro";
                name = "GPT 5.4 Pro";
                reasoning = true;
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 1048576;
              }
            ];
          };
        };

        skills.install.nodeManager = "bun";
      };
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

  # Minimal system packages (most packages managed by Home Manager)
  environment.systemPackages = with pkgs; [
    cloudflared
    curl
    dnsutils
    openclaw-gateway
    wget
    vim
    # Kubernetes tools
    kubectl
    k9s
    # Ghostty terminfo (SSH 접속 시 xterm-ghostty TERM 인식용)
    ghostty.terminfo
  ];

  # Enable zsh system-wide (configuration via Home Manager)
  programs.zsh.enable = true;

  # Enable nix-ld for running dynamically linked binaries (e.g., bun plugins)
  programs.nix-ld.enable = true;

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Firewall - open ports for services
  networking.firewall.allowedTCPPorts = [
    8080 # Code Server
    3923 # Copyparty
    2283 # Immich
  ];

  # Security
  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Users
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio gytk.kim@gmail.com"
  ]
  ++ (args.extraPublicKeys or [ ]);

  users.users.gytkk = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio gytk.kim@gmail.com"
    ];
  };

  # Locale - SSH 접속 시 클라이언트에서 전달되는 ko_KR.UTF-8 지원
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ko_KR.UTF-8/UTF-8"
  ];

  system.stateVersion = "25.11";
}
