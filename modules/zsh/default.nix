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

    # Use XDG config directory for zsh configuration files
    dotDir = "${config.xdg.configHome}/zsh";

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

      # antigravity
      agy = "antigravity";
    };

    # Environment variables
    sessionVariables = { };

    # Initialize p10k configuration
    # https://nix-community.github.io/home-manager/options.xhtml#opt-programs.zsh.initContent
    initContent =
      let
        earlyInit = lib.mkOrder 500 ''
          # Load Nix if not ready
          if [[ ! $(command -v nix) && -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]]; then
            source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
          fi
        '';

        zshConfig = lib.mkOrder 1000 ''
          # Initialize p10k configuration
          [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

          # gh auth 후 자동으로 ~/.netrc 업데이트 (Nix flake용)
          gh-auth-netrc() {
            gh auth "$@"
            if [[ $? -eq 0 ]] && gh auth status &>/dev/null; then
              local token=$(gh auth token 2>/dev/null)
              if [[ -n "$token" ]]; then
                # 기존 github.com 항목 제거 후 새로 추가
                grep -v "machine github.com" ~/.netrc > ~/.netrc.tmp 2>/dev/null || touch ~/.netrc.tmp
                echo "machine github.com login oauth password $token" >> ~/.netrc.tmp
                mv ~/.netrc.tmp ~/.netrc
                chmod 600 ~/.netrc
                echo "Updated ~/.netrc with GitHub token for Nix"
              fi
            fi
          }

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

          # Initialize micromamba
          if command -v micromamba > /dev/null; then
            eval "$(micromamba shell hook --shell zsh)"
          fi
        '';
      in
      lib.mkMerge [
        earlyInit
        zshConfig
      ];
  };

  # fzf configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # Copy p10k configuration file to home directory
  home.file.".p10k.zsh".source = ./p10k.zsh;
}
