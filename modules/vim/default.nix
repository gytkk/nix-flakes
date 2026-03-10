{
  config,
  flakeDirectory,
  ...
}:

let
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/vim/${path}";
in
{
  xdg.configFile."nvim/lua/config".source = mkSymlink "files/config";
  xdg.configFile."nvim/onelight.lua".source = mkSymlink "files/onelight.lua";

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    initLua = "require('config')";
  };
}
