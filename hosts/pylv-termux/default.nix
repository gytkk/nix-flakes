{ pkgs, ... }:
{
  # This target is deliberately independent from base/default.nix. Most desktop
  # and server modules assume systemd, glibc, or a conventional Linux home.
  system.stateVersion = "24.05";

  # nix-on-droid's module API still exposes this as a string rather than
  # nix.settings, unlike current NixOS and Home Manager modules.
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  environment.packages = with pkgs; [
    bat
    eza
    fd
    git
    jq
    neovim
    ripgrep
    tmux
    unzip
    wget
    zsh
  ];

  # nix-on-droid bundles Home Manager. Keep Android-specific user configuration
  # here rather than importing the workstation-wide Home Manager module stack.
  home-manager.config = {
    home.stateVersion = "24.05";

    programs = {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      git.enable = true;
      zsh = {
        enable = true;
        autosuggestion.enable = true;
        syntaxHighlighting.enable = true;
      };
    };
  };
}
