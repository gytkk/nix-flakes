{ config, pkgs, zsh-powerlevel10k, ... }:

{
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
        "git"
        "docker"
        "terraform"
        "aws"
        "kubectl"
        "fzf"
        "z"
      ]
    };

    plugins = [
      {
        # Powerlevel10k theme
        name = "powerlevel10k";
        src = zsh-powerlevel10k;
        file = "powerlevel10k.zsh-theme";
      }
    ];

    shellAliases = {
      # ls aliases with color by default
      ls = "ls --color=auto";
      ll = "ls -la --color=auto";
      lh = "ls -lh --color=auto";

      # Neovim
      vim = "nvim";
      vi = "nvim";

      # k8s aliases
      kl = "kubectl";
      kx = "kubectx";
      kn = "kubens";
    };
  };

  # fzf configuration
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # direnv
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };
}
