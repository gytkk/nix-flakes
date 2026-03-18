{
  config,
  lib,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.helix;
in
{
  options.modules.helix = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Helix editor module";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.helix.enable = true;

    # config.toml → repo 파일로 직접 symlink (mutable)
    xdg.configFile."helix/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/helix/files/config.toml";

    # 커스텀 테마 → repo 파일로 직접 symlink (mutable)
    xdg.configFile."helix/themes/custom_onelight.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/helix/themes/custom_onelight.toml";
  };
}
