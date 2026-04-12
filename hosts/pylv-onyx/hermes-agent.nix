{
  pkgs,
  inputs,
  username,
  homeDirectory,
  ...
}:
let
  hermesPackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  stateDir = "${homeDirectory}/.hermes-service";
  hermesHome = "${stateDir}/.hermes";
  workingDirectory = "${stateDir}/workspace";
in
{
  services.hermes-agent = {
    enable = true;
    package = hermesPackage;

    # Run as the main user, similar to the current OpenClaw setup.
    user = username;
    group = "users";
    createUser = false;

    # Keep service-managed runtime state separate from the user's personal
    # ~/.hermes CLI sandbox, while still living under the home directory.
    stateDir = stateDir;
    workingDirectory = workingDirectory;

    # Install the CLI system-wide too, so `hermes` is available even outside
    # Home Manager contexts. We intentionally do NOT force shared HERMES_HOME
    # in shells; use the helper alias when you want to inspect service state.
    addToSystemPackages = false;

    # Only manage a few baseline settings declaratively. User-added settings in
    # config.yaml are preserved by the upstream deep-merge activation logic.
    settings = {
      terminal.backend = "local";
      display.tool_progress = "off";
    };

    extraPackages = with pkgs; [
      git
      nodejs
      bun
      uv
      ripgrep
      fd
      jq
      wget
      curl
      ffmpeg
    ];
  };

  environment.systemPackages = [ hermesPackage ];

  environment.sessionVariables = {
    HERMES_SERVICE_STATE_DIR = stateDir;
    HERMES_SERVICE_HOME = hermesHome;
  };
}
