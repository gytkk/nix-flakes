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
    __pycache__/
    *.py[codz]
    *$py.class.Python

    build/
    develop-eggs/
    dist/
    downloads/
    eggs/
    .eggs/
    parts/
    sdist/
    wheels/
    share/python-wheels/
    *.egg-info/
    .installed.cfg
    *.egg
    MANIFEST

    .coverage
    htmlcov/

    .ruff_cache/

    # Node.js
    logs
    *.log
    npm-debug.log*
    yarn-debug.log*
    yarn-error.log*
    lerna-debug.log*

    # Nix
    result
    result-*

    # Claude
    .claude/settings.local.json
  '';
}
