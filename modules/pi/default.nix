{
  config,
  lib,
  pkgs,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.pi;
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/pi/${path}";
in
{
  options.modules.pi.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Pi coding agent CLI";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.pi
    ];

    home.file.".pi/agent/AGENTS.md".source = mkSymlink "files/AGENTS.md";
    home.file.".pi/agent/settings.json".source = mkSymlink "files/settings.json";
    home.file.".pi/agent/extensions/codex-fast-mode.ts".source =
      mkSymlink "files/extensions/codex-fast-mode.ts";
    home.file.".pi/agent/skills".source = mkSymlink "skills";
  };
}
