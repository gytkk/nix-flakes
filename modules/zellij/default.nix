{
  config,
  pkgs,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/zellij/${path}";
  configSource =
    if pkgs.stdenv.isDarwin then
      pkgs.writeText "zellij-config.kdl" ''
        copy_command "pbcopy"
        ${builtins.readFile ./files/config.kdl}
      ''
    else
      mkSymlink "files/config.kdl";
in

{
  home.packages = [ pkgs.zellij ];

  xdg.configFile."zellij/config.kdl".source = configSource;
}
