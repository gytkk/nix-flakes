{
  config,
  pkgs,
  inputs,
  flakeDirectory,
  ...
}:

let
  # 두 테마 소스를 하나의 디렉토리로 병합
  combinedThemes = pkgs.symlinkJoin {
    name = "ghostty-themes";
    paths = [
      "${inputs.rose-pine-ghostty}/dist"
      "${inputs.catppuccin-ghostty}/themes"
    ];
  };
in
{
  xdg.configFile."ghostty/themes".source = combinedThemes;

  # config → repo 파일로 직접 symlink (mutable)
  xdg.configFile."ghostty/config".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/ghostty/files/config";
}
