{
  config,
  pkgs,
  lib,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.codex;
in
{
  options.modules.codex = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Codex CLI module";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.codex ];

    home.file.".codex/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/codex/files/config.toml";
    home.file.".codex/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/codex/files/AGENTS.md";
  };
}
