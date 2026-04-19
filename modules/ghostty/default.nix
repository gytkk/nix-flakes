{
  config,
  flakeDirectory,
  themeExports,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/ghostty/${path}";
  ghosttyThemeEntries = builtins.readDir (themeExports.dir "ghostty");
  ghosttyThemeFiles = builtins.filter (
    fileName:
    let
      fileType = ghosttyThemeEntries.${fileName};
    in
    fileType == "regular" || fileType == "symlink"
  ) (builtins.attrNames ghosttyThemeEntries);
  ghosttyThemeLinks = builtins.listToAttrs (
    map (fileName: {
      name = "ghostty/themes/${fileName}";
      value.source = config.lib.file.mkOutOfStoreSymlink (themeExports.mutableFile "ghostty" fileName);
    }) ghosttyThemeFiles
  );
in
{
  xdg.configFile = ghosttyThemeLinks // {
    "ghostty/config".source = mkSymlink "files/config";
    "ghostty/themes/nix-flakes-current.conf".source = config.lib.file.mkOutOfStoreSymlink (
      themeExports.mutableFile "ghostty" "${config.modules.commonTheme}.conf"
    );
  };
}
