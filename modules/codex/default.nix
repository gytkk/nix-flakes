{
  config,
  pkgs,
  lib,
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

    home.file.".codex/config.toml".source = ./files/config.toml;
    home.file.".codex/AGENTS.md".source = ./files/AGENTS.md;
  };
}
