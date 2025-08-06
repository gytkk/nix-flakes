{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    zsh
    zsh-powerlevel10k
  ];

  # Zsh configuration
  programs.zsh = {
    enable = true;

    # Enable features
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # History
    history = {
      size = 10000;
      save = 10000;
      path = "${config.home.homeDirectory}/.zsh_history";
      ignoreDups = true;
      share = true;
      extended = true;
    };

    # Oh-My-Zsh configuration
    oh-my-zsh = {
      enable = true;

      plugins = [
        "direnv"
        "fzf"
        "git"
        "docker"
        "aws"
        "kubectl"
        "z"
      ];
    };

    plugins = [
      {
        # Powerlevel10k theme
        name = "powerlevel10k";
        src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/";
        file = "powerlevel10k.zsh-theme";
      }
    ];

    shellAliases = {
      # Home manager aliases
      hm = "home-manager";
      hmb = "home-manager build";
      hms = "home-manager switch";

      # ls aliases with color by default
      ls = "ls --color=auto";
      ll = "ls -la --color=auto";
      lh = "ls -lh --color=auto";

      # Neovim
      vim = "nvim";
      vi = "nvim";
      vimdiff = "nvim -d";

      # k8s aliases
      kl = "kubectl";
      kx = "kubectx";
      kn = "kubens";

      # uv
      ur = "uv run";
    };

    # Environment variables
    sessionVariables = { };

    # Initialize p10k configuration
    initContent = ''
      # Initialize p10k configuration
      [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

      # Initialize mise
      if command -v mise > /dev/null; then
        eval "$(mise activate zsh)"
      fi

      # Enable colors
      autoload -U colors && colors

      # Ensure oh-my-zsh cache directory has proper permissions
      if [ -d "$HOME/.cache/oh-my-zsh" ]; then
        chmod -R 755 "$HOME/.cache/oh-my-zsh" 2>/dev/null || true
      else
        mkdir -p "$HOME/.cache/oh-my-zsh"
        chmod -R 755 "$HOME/.cache/oh-my-zsh" 2>/dev/null || true
      fi

      # Set zsh completion to use LS_COLORS
      zstyle ':completion:*' list-colors "$LS_COLORS"

      # Set uv shell completion
      if command -v uv > /dev/null; then
        eval "$(uv generate-shell-completion zsh)"
      fi
    '';

    initContent = ''
      if [[ ! $(command -v nix) && -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]]; then
        source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi
    '';
  };

  # fzf configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Copy p10k configuration file to home directory
  home.file.".p10k.zsh".source = ./p10k.zsh;
}
