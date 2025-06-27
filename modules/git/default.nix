{
  config,
  lib,
  pkgs,
  environmentConfig ? null,
  ...
}:
with lib;

{
  programs.git = {
    enable = true;
    userName = if environmentConfig != null then environmentConfig.git.userName else "gytkk";
    userEmail = if environmentConfig != null then environmentConfig.git.userEmail else "gytk.kim@gmail.com";

    lfs.enable = true;

    extraConfig = {
      core = {
        editor = "nvim";
        excludesfile = "~/.gitignore";
      };

      # Diff configuration
      diff = {
        tool = "vimdiff";
      };

      # Pull configuration
      pull = {
        rebase = true;
        ff = "only";
      };

      push = {
        default = "current";
        autoSetupRemote = true;
      };

      # Color configuration
      color = {
        ui = "auto";
        diff = "auto";
        status = "auto";
        branch = "auto";
      };

      # Init configuration
      init = {
        defaultBranch = "main";
      };
    };
  };

  # Create .gitignore file
  home.file.".gitignore".text = ''
    .DS_Store
    .idea
    .vscode
    .tool-versions

    # Environment
    .env
    .envrc
    mise.toml

    # Python
    .coverage
  '';
}
