{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.git = {
    enable = true;
    userName = "gytkk";
    userEmail = "gytk.kim@gmail.com";

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

    # Claude
    .claude/settings.local.json
  '';
}
