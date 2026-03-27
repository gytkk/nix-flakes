{
  config,
  pkgs,
  ...
}@args:
{
  imports = [
    ./hardware-configuration.nix
    ./openclaw.nix
  ];

  boot.loader.systemd-boot.enable = true;
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

  # niri compositor
  programs.niri.enable = true;

  # DankMaterialShell greeter (SDDM 대체)
  services.dank-material-shell.greeter = {
    enable = true;
    compositor.name = "niri";
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

  services.openssh = {
    enable = true;
    # Ghostty ssh-env가 전달하는 터미널 환경 변수 수락 (Claude Code TUI 렌더링에 필요)
    extraConfig = ''
      AcceptEnv COLORTERM TERM_PROGRAM TERM_PROGRAM_VERSION
    '';
  };
  services.tailscale.enable = true;

  # 노트북 덮개를 닫아도 suspend하지 않음 (서버 용도)
  services.logind.lidSwitch = "ignore";
  services.logind.lidSwitchExternalPower = "ignore";
  services.logind.lidSwitchDocked = "ignore";

  # /bin/bash shebang 호환성 (서드파티 스크립트용)
  system.activationScripts.binbash = ''
    ln -sfn ${pkgs.bash}/bin/bash /bin/bash
  '';

  # Hostname
  networking.hostName = "pylv-onyx";

  # Minimal system packages (most packages managed by Home Manager)
  environment.systemPackages = with pkgs; [
    curl
    dnsutils
    wget
    vim
    # Ghostty terminfo (SSH 접속 시 xterm-ghostty TERM 인식용)
    ghostty.terminfo
    # X11 앱 호환 (Electron 등)
    xwayland-satellite-stable
  ];

  # Wayland 네이티브 Electron 앱 지원
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # Enable zsh system-wide (configuration via Home Manager)
  programs.zsh.enable = true;

  # Enable nix-ld for running dynamically linked binaries (e.g., bun plugins)
  programs.nix-ld.enable = true;

  # Enable flakes
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Caps Lock → Left Ctrl (커널 레벨, 모든 DE/TTY에서 동작)
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings.main.capslock = "leftcontrol";
    };
  };

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

  # CJK fallback 글꼴
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Sarasa Gothic K" ];
    serif = [ "Sarasa Gothic K" ];
    monospace = [ "Sarasa Mono K" ];
  };

  # Locale - SSH 접속 시 클라이언트에서 전달되는 ko_KR.UTF-8 지원
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ko_KR.UTF-8/UTF-8"
  ];

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
