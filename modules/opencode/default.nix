{
  config,
  pkgs,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/opencode/${path}";
in
{
  # Install OpenCode via gytkk/flake-stores (pre-built binaries)
  home.packages = [
    pkgs.opencode
  ];

  # Create ~/.config/opencode/opencode.json file
  home.file.".config/opencode/opencode.json".source = mkSymlink "files/opencode.json";

  # Create ~/.config/opencode/oh-my-openagent.json file (oh-my-opencode plugin config)
  home.file.".config/opencode/oh-my-openagent.json".source = mkSymlink "files/oh-my-openagent.json";

  # Deploy native notification plugin (uses OSC 777 for Ghostty desktop notifications)
  home.file.".config/opencode/plugins/native-notify.ts".source =
    mkSymlink "files/plugins/native-notify.ts";

  # Create ~/.config/opencode/AGENTS.md file
  home.file.".config/opencode/AGENTS.md".source = mkSymlink "files/AGENTS.md";
}
