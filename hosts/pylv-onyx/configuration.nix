{
  config,
  inputs,
  pkgs,
  ...
}:
{
  imports = [
    inputs.disko.nixosModules.disko
    inputs.niri.nixosModules.niri
    inputs.dms.nixosModules.dank-material-shell
    inputs.dms.nixosModules.greeter
    ./hardware-configuration.nix
    ../../modules/openclaw
    ../../modules/nixos
  ];

  modules.openclaw = {
    enable = true;
    lanInterface = "wlo1";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.graceful = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;

  # NVIDIA GTX 1650 Mobile (Turing) — offload 모드: 평소 Intel iGPU, 필요 시 nvidia-offload 명령으로 사용
  hardware.nvidia = {
    modesetting.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:87:0:0";
    };
  };

  networking.networkmanager.enable = true;
  networking.hostName = "pylv-onyx";

  users.users.gytkk.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPSLJRqb27foz3LyICtfk8A+VyyjXdkjQOp6rG+MX28E u0_a391@localhost"
  ];

  # Keep direct `nixos-rebuild switch` from attempting the dbus -> broker live migration.
  services.dbus.implementation = "dbus";

  # n8n is reachable only through the Tailscale-facing nginx origin. The
  # Cloudflare Tunnel connector runs on pylv-sepia and targets this listener.
  services.n8n = {
    enable = true;
    environment = {
      N8N_HOST = "n8n.pylv.dev";
      N8N_PROTOCOL = "https";
      N8N_EDITOR_BASE_URL = "https://n8n.pylv.dev";
      WEBHOOK_URL = "https://n8n.pylv.dev/";
      N8N_PROXY_HOPS = 1;
      N8N_SECURE_COOKIE = true;
      N8N_LISTEN_ADDRESS = "127.0.0.1";
    };
  };

  # Internal JavaScript task runners spawn node by name.
  systemd.services.n8n.path = [ pkgs.nodejs ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts."n8n-tailscale-origin" = {
      serverName = "_";
      listen = [
        {
          addr = "0.0.0.0";
          port = 12370;
        }
      ];
      locations."/" = {
        proxyPass = "http://127.0.0.1:5678";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-Host $host;
          proxy_set_header X-Forwarded-Proto https;
        '';
      };
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 12370 ];

  # niri compositor
  programs.niri.enable = true;

  # DankMaterialShell
  programs.dank-material-shell = {
    enable = true;
    greeter = {
      enable = true;
      compositor.name = "niri";
    };
  };

  services.libinput = {
    enable = true;
    touchpad.naturalScrolling = true;
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;

  # 노트북 덮개를 닫아도 suspend하지 않음 (서버 용도)
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  # Caps Lock → Left Ctrl (커널 레벨, 모든 DE/TTY에서 동작)
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "leftcontrol";
    };
  };

  # Host-specific packages
  environment.systemPackages = with pkgs; [
    # X11 앱 호환 (Electron 등)
    xwayland-satellite-stable
  ];

  # Wayland Electron support and headless user-systemd defaults for login shells.
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # CJK fallback 글꼴
  fonts.fontconfig.defaultFonts = {
    sansSerif = [
      "Pretendard"
      "Sarasa Gothic K"
    ];
    serif = [ "Sarasa Gothic K" ];
    monospace = [ "Sarasa Mono K" ];
  };

  # 한글 입력기
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-hangul
      fcitx5-gtk
    ];
  };

  system.stateVersion = "25.11";
}
