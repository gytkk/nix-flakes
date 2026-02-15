{
  config,
  lib,
  pkgs,
  isWSL ? false,
  ...
}:

{
  home.packages = with pkgs; [
    zsh
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

    shellAliases = {
      # Home manager aliases
      hm = "home-manager";
      hmb = "home-manager build";
      hms = "home-manager switch";

      # ls aliases with color by default
      ls = "ls --color=auto";
      ll = "ls -la --color=auto";
      lh = "ls -lh --color=auto";

      # git
      ga = "git add";
      gb = "git branch";
      gc = "git commit";
      gp = "git push";
      gl = "git pull";
      gst = "git status";
      gsw = "git switch";
      gco = "git checkout";
      gd = "git diff";

      # Neovim
      vim = "nvim";
      vi = "nvim";
      vimdiff = "nvim -d";

      # OpenCode
      # k8s aliases
      kl = "kubectl";
      kx = "kubectx";
      kn = "kubens";

      # antigravity
      agy = "antigravity";
    }
    // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
      zed = if isWSL then "zed.exe" else "zeditor";
    };

    # Environment variables
    sessionVariables = {
      SHELL = "${pkgs.zsh}/bin/zsh";
    };

    # Zsh initialization
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

          # History prefix search with up/down arrows
          autoload -U up-line-or-beginning-search down-line-or-beginning-search
          zle -N up-line-or-beginning-search
          zle -N down-line-or-beginning-search
          # ^[[A/^[[B: normal mode (macOS, some Linux terminals)
          # ^[OA/^[OB: application mode (Linux, WSL, tmux)
          bindkey "^[[A" up-line-or-beginning-search
          bindkey "^[[B" down-line-or-beginning-search
          bindkey "^[OA" up-line-or-beginning-search
          bindkey "^[OB" down-line-or-beginning-search

          # Home/End key bindings (for vi mode compatibility)
          # ^[[H/^[[F: normal mode, ^[OH/^[OF: application mode
          bindkey "^[[H" beginning-of-line
          bindkey "^[[F" end-of-line
          bindkey "^[OH" beginning-of-line
          bindkey "^[OF" end-of-line
          bindkey -M vicmd "^[[H" beginning-of-line
          bindkey -M vicmd "^[[F" end-of-line
          bindkey -M vicmd "^[OH" beginning-of-line
          bindkey -M vicmd "^[OF" end-of-line

          # Enable colors
          autoload -U colors && colors

          # Set zsh completion to use LS_COLORS
          zstyle ':completion:*' list-colors "$LS_COLORS"

          # Set uv shell completion
          if command -v uv > /dev/null; then
            eval "$(uv generate-shell-completion zsh)"
          fi

          # OpenCode with tmux subagent support
          oc() {
            local base_name
            local path_hash
            local session_name
            local oc_port

            base_name=$(basename "$PWD")

            if command -v md5sum >/dev/null 2>&1; then
              path_hash=$(printf '%s' "$PWD" | md5sum | cut -c1-4)
            else
              path_hash=$(printf '%s' "$PWD" | md5 | cut -c10-13)
            fi

            session_name="$base_name-$path_hash"

            # Find available port
            oc_port=4096
            while [ "$oc_port" -lt 5096 ]; do
              if ! lsof -i :$oc_port >/dev/null 2>&1; then
                break
              fi
              oc_port=$((oc_port + 1))
            done

            export OPENCODE_PORT=$oc_port

            if [ -n "$TMUX" ]; then
              opencode --port "$oc_port" "$@"
            else
              local oc_cmd
              oc_cmd="OPENCODE_PORT=$oc_port opencode --port $oc_port $*; exec $SHELL"

              if tmux has-session -t "$session_name" 2>/dev/null; then
                tmux new-window -t "$session_name" -c "$PWD" "$oc_cmd"
                tmux attach-session -t "$session_name"
              else
                tmux new-session -s "$session_name" -c "$PWD" "$oc_cmd"
              fi
            fi
          }

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

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  # Starship configuration from TOML file
  # Style: Jetpack (minimalist) + Catppuccin Latte colors
  xdg.configFile."starship.toml".source = ./starship.toml;

  # zoxide (replacement for z)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # fzf configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # direnv configuration
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };
}
