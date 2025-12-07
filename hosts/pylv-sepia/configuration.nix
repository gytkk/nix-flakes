{
  modulesPath,
  lib,
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
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
  services.openssh.enable = true;
  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    # System utilities
    curl
    wget
    htop
    tmux
    less
    direnv

    # Development
    git
    git-lfs
    gh
    delta
    lazygit
    vim
    jq
    ripgrep
    fd
    fzf
    bat

    # Zsh
    zsh-powerlevel10k
    zsh-autosuggestions
    zsh-syntax-highlighting

    # Python
    uv

    # Node.js
    nodejs
    pnpm

    # Go
    go

    # Rust
    rustup

    # Nix
    nixfmt-rfc-style

    # Code Server
    code-server
  ];

  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
    ohMyZsh = {
      enable = true;
      plugins = [ "git" "docker" "kubectl" "z" "fzf" ];
    };
    promptInit = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
    '';
    shellAliases = {
      ls = "ls --color=auto";
      ll = "ls -la --color=auto";
      vim = "nvim";
      vi = "nvim";
      kl = "kubectl";
      kx = "kubectx";
    };
  };

  # Git system-wide config
  programs.git = {
    enable = true;
    lfs.enable = true;
    config = {
      user = {
        name = "gytkk";
        email = "gytk.kim@gmail.com";
      };
      core = {
        editor = "vim";
        pager = "delta";
      };
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
      pull.rebase = true;
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      init.defaultBranch = "main";
      fetch = {
        prune = true;
        pruneTags = true;
      };
    };
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

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

  system.stateVersion = "25.11";
}
